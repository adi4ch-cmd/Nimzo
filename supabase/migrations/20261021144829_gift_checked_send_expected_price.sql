-- REVIEW/STAGING PROPOSAL ONLY. No live mutation or historical ledger rewrite.
-- Add opt-in price confirmation without changing legacy RPCs or settlement.
-- The client must verify approved media bytes before a NEW send. A receipt
-- lookup may precede media preflight to recover a lost successful response.
begin;

create or replace function nimzo_private.gift_send_receipt_checked(
  p_receiver uuid, p_gift uuid, p_qty integer, p_key text,
  p_expected_total bigint, p_scope text, p_context uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_sender uuid := auth.uid();
  v_kind text;
  v_context_key text;
  v_count integer;
  v_sent public.ledger%rowtype;
  v_total bigint;
  v_diamonds bigint;
  v_result jsonb;
begin
  if v_sender is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_receiver is null or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999
    or p_expected_total is null or p_expected_total<0
    or p_scope is null or p_scope not in ('room','moment','profile')
    or (p_scope='profile' and p_context is not null)
    or (p_scope in ('room','moment') and p_context is null) then
    raise exception 'invalid checked gift request' using errcode='22023';
  end if;
  if nullif(btrim(p_key),'') is null or length(p_key)>200 then
    raise exception 'idempotency key required' using errcode='22023';
  end if;
  v_kind := case p_scope when 'room' then 'gift_sent'
    when 'moment' then 'moment_gift_sent' else 'profile_gift_sent' end;
  v_context_key := case p_scope when 'room' then 'room'
    when 'moment' then 'moment' else 'profile' end;

  -- A key reused for another kind is a collision, never proof of payment.
  -- Scope by authenticated sender; another account cannot inspect this receipt.
  select count(*) into v_count from public.ledger l
    where l.user_id=v_sender and l.idempotency_key=p_key||':sender';
  if v_count=0 then return null; end if;
  if v_count<>1 then
    raise exception 'idempotency payload mismatch' using errcode='22023';
  end if;
  select l.* into v_sent from public.ledger l
    where l.user_id=v_sender and l.idempotency_key=p_key||':sender';
  if v_sent.kind is distinct from v_kind
    or v_sent.ref->>'gift' is distinct from p_gift::text
    or v_sent.ref->>'qty' is distinct from p_qty::text
    or v_sent.ref->>v_context_key is distinct from
      (case when p_scope='profile' then p_receiver else p_context end)::text
    or (p_scope<>'profile' and v_sent.ref->>'receiver' is distinct from p_receiver::text)
    or v_sent.coin_delta is null or v_sent.coin_delta>0
    or v_sent.coin_delta::numeric <> -p_expected_total::numeric then
    raise exception 'idempotency payload mismatch' using errcode='22023';
  end if;
  v_total := p_expected_total; -- Verified against the ORIGINAL debit, not today's price.
  select l.diamond_delta into v_diamonds from public.ledger l
    where l.user_id=p_receiver and l.idempotency_key=p_key||':receiver'
      and l.kind=case p_scope when 'room' then 'gift_received'
        when 'moment' then 'moment_gift_received' else 'profile_gift_received' end
      and l.ref->>'from'=v_sender::text and l.ref->>'gift'=p_gift::text
      and l.ref->>'qty'=p_qty::text
      and l.ref->>v_context_key=(case when p_scope='profile' then p_receiver else p_context end)::text;
  if not found or v_diamonds is null or v_diamonds<0 then
    raise exception 'gift receipt incomplete' using errcode='22023';
  end if;
  v_result := jsonb_build_object('status','replayed','total',v_total,'diamonds',v_diamonds);
  if p_scope='room' then
    -- Preserve legacy response semantics: nominal 5% even when the sender
    -- owns the room and the original RPC deliberately did NOT credit it.
    v_result := v_result || jsonb_build_object('room_coins',v_total*5/100);
  end if;
  return v_result;
end;
$$;

create or replace function nimzo_private.send_gift_checked(
  p_receiver uuid, p_gift uuid, p_qty integer, p_key text,
  p_expected_total bigint, p_scope text, p_context uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_sender uuid := auth.uid();
  v_receipt jsonb;
  v_price bigint;
  v_result jsonb;
begin
  if v_sender is null then raise exception 'not authenticated' using errcode='28000'; end if;
  -- Serialize checked requests across scopes and preserve each OLD RPC's
  -- advisory lock so checked/legacy concurrent retries also settle once.
  -- Do not hold a catalog row while waiting for an idempotency lock.
  if nullif(btrim(p_key),'') is null or length(p_key)>200 then
    raise exception 'idempotency key required' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_sender::text||':'||p_key,0));
  if p_scope in ('room','moment') then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      (case when p_scope='room' then 'gift_sent:' else 'moment_gift_sent:' end)
      ||v_sender::text||':'||p_key,0));
  end if;
  v_receipt := nimzo_private.gift_send_receipt_checked(
    p_receiver,p_gift,p_qty,p_key,p_expected_total,p_scope,p_context);
  if v_receipt is not null then return v_receipt; end if;

  -- FOR SHARE conflicts with UPDATE of active/coin_price until the entire
  -- original atomic settlement and its media/permission triggers finish.
  select g.coin_price into v_price from public.gifts g
    where g.id=p_gift and g.active for share;
  if not found or v_price is null or v_price<0 then
    raise exception 'gift unavailable' using errcode='22023';
  end if;
  if v_price::numeric*p_qty::numeric <> p_expected_total::numeric then
    raise exception 'gift price changed; confirm the current price' using errcode='22023';
  end if;
  if p_scope='room' then
    v_result := public.send_gift(p_context,p_receiver,p_gift,p_qty,p_key);
  elsif p_scope='moment' then
    v_result := public.send_moment_gift(p_context,p_receiver,p_gift,p_qty,p_key);
  else
    v_result := nimzo_private.send_profile_gift(p_receiver,p_gift,p_qty,p_key);
  end if;
  return v_result;
end;
$$;

create or replace function public.gift_send_receipt_checked(
  p_receiver uuid, p_gift uuid, p_qty integer, p_key text,
  p_expected_total bigint, p_scope text, p_context uuid
) returns jsonb language sql stable security invoker set search_path='' as $$
  select nimzo_private.gift_send_receipt_checked(
    p_receiver,p_gift,p_qty,p_key,p_expected_total,p_scope,p_context)
$$;
create or replace function public.send_gift_checked(
  p_room uuid,p_receiver uuid,p_gift uuid,p_qty integer,p_key text,p_expected_total bigint
) returns jsonb language sql security invoker set search_path='' as $$
  select nimzo_private.send_gift_checked(p_receiver,p_gift,p_qty,p_key,p_expected_total,'room',p_room)
$$;
create or replace function public.send_moment_gift_checked(
  p_moment uuid,p_receiver uuid,p_gift uuid,p_qty integer,p_key text,p_expected_total bigint
) returns jsonb language sql security invoker set search_path='' as $$
  select nimzo_private.send_gift_checked(p_receiver,p_gift,p_qty,p_key,p_expected_total,'moment',p_moment)
$$;
create or replace function public.send_profile_gift_checked(
  p_receiver uuid,p_gift uuid,p_qty integer,p_key text,p_expected_total bigint
) returns jsonb language sql security invoker set search_path='' as $$
  select nimzo_private.send_gift_checked(p_receiver,p_gift,p_qty,p_key,p_expected_total,'profile',null)
$$;

revoke all on function nimzo_private.gift_send_receipt_checked(uuid,uuid,integer,text,bigint,text,uuid) from public,anon,authenticated;
revoke all on function nimzo_private.send_gift_checked(uuid,uuid,integer,text,bigint,text,uuid) from public,anon,authenticated;
revoke all on function public.gift_send_receipt_checked(uuid,uuid,integer,text,bigint,text,uuid) from public,anon,authenticated;
revoke all on function public.send_gift_checked(uuid,uuid,uuid,integer,text,bigint) from public,anon,authenticated;
revoke all on function public.send_moment_gift_checked(uuid,uuid,uuid,integer,text,bigint) from public,anon,authenticated;
revoke all on function public.send_profile_gift_checked(uuid,uuid,integer,text,bigint) from public,anon,authenticated;
grant usage on schema nimzo_private to authenticated;
grant execute on function nimzo_private.gift_send_receipt_checked(uuid,uuid,integer,text,bigint,text,uuid) to authenticated;
grant execute on function nimzo_private.send_gift_checked(uuid,uuid,integer,text,bigint,text,uuid) to authenticated;
grant execute on function public.gift_send_receipt_checked(uuid,uuid,integer,text,bigint,text,uuid) to authenticated;
grant execute on function public.send_gift_checked(uuid,uuid,uuid,integer,text,bigint) to authenticated;
grant execute on function public.send_moment_gift_checked(uuid,uuid,uuid,integer,text,bigint) to authenticated;
grant execute on function public.send_profile_gift_checked(uuid,uuid,integer,text,bigint) to authenticated;
commit;

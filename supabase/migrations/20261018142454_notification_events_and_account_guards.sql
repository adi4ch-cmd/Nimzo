-- Enrich future events only; no historical notices or economy changes.
alter table public.notifications add column room_id uuid references public.rooms(id) on delete set null;
alter table public.notifications add column event_key text;
create index notifications_room_id on public.notifications(room_id);
create unique index notifications_event_key on public.notifications(user_id,event_key) where event_key is not null;
grant select(room_id,event_key) on public.notifications to authenticated;
create or replace function public.send_message(p_to uuid,p_body text,p_kind text default 'text') returns void
language plpgsql security definer set search_path='' as $$
declare sender uuid:=auth.uid(); message_id uuid;
begin
 if sender is null or not exists(select 1 from public.profiles where id=sender and status='active') then raise exception 'Active account required' using errcode='42501';end if;
 if p_to is null or not exists(select 1 from public.profiles where id=p_to and status='active') then raise exception 'Recipient unavailable' using errcode='42501';end if;
 if p_kind is null or p_kind not in('text','emoji','room_invite') then raise exception 'kind not allowed';end if;
 if char_length(coalesce(p_body,''))=0 or char_length(p_body)>1000 then raise exception 'bad message';end if;
 if exists(select 1 from public.blocks where(blocker_id=p_to and blocked_id=sender) or(blocker_id=sender and blocked_id=p_to)) then raise exception 'cannot message this user';end if;
 insert into public.messages(sender_id,receiver_id,kind,body) values(sender,p_to,p_kind,p_body) returning id into message_id;
 insert into public.notifications(user_id,category,title,body,actor_id,event_type,event_key)
 values(p_to,'messages','New message',left(p_body,80),sender,'personal_message','message:'||message_id::text)
 on conflict(user_id,event_key) where event_key is not null do nothing;
end$$;
revoke all on function public.send_message(uuid,text,text) from public,anon;
grant execute on function public.send_message(uuid,text,text) to authenticated;
create or replace function nimzo_private.notify_gift_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare gift_name text;
begin
 if new.receiver_id is null then return new;end if;
 select name into gift_name from public.gifts where id=new.gift_id;
 insert into public.notifications(user_id,category,title,body,actor_id,event_type,event_key,room_id)
 values(new.receiver_id,'gifts','Gift received',left(coalesce(gift_name,'Gift')||' × '||new.quantity::text,200),new.sender_id,'gift_received','gift:'||new.id::text,new.room_id)
 on conflict(user_id,event_key) where event_key is not null do nothing;
 return new;
end$$;
revoke all on function nimzo_private.notify_gift_event() from public,anon,authenticated;
create function nimzo_private.notify_followed_room_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner uuid;
begin
 select owner_id into owner from public.rooms where id=new.room_id and status='open' and owner_id=new.user_id;
 if owner is null then return new;end if;
 insert into public.notifications(user_id,category,title,body,actor_id,event_type,event_key,room_id)
 select f.user_id,'rooms','Room is active','A room you follow is active.',owner,'followed_room_activity',
 'room-live:'||new.room_id::text||':'||floor(extract(epoch from clock_timestamp())/3600)::text,new.room_id
 from public.room_follows f join public.profiles p on p.id=f.user_id and p.status='active'
 where f.room_id=new.room_id and f.user_id<>owner and not exists(select 1 from public.blocks b where
 (b.blocker_id=owner and b.blocked_id=f.user_id) or(b.blocker_id=f.user_id and b.blocked_id=owner))
 on conflict(user_id,event_key) where event_key is not null do nothing;
 return new;
end$$;
revoke all on function nimzo_private.notify_followed_room_activity() from public,anon,authenticated;
create trigger notify_followed_room_activity after insert on public.room_members for each row execute function nimzo_private.notify_followed_room_activity();
create function nimzo_private.send_admin_announcement(p_title text,p_body text,p_key text) returns integer
language plpgsql security definer set search_path='' as $$
declare total integer;
begin
 if auth.uid() is null or not public.is_admin() or not exists(select 1 from public.profiles where id=auth.uid() and status='active') then raise exception 'Admin required' using errcode='42501';end if;
 if p_title is null or char_length(btrim(p_title)) not between 1 and 120 or p_body is null or char_length(p_body)>1000
 or p_key is null or p_key !~ '^[A-Za-z0-9_-]{1,128}$' then raise exception 'Invalid announcement' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('admin-notice:'||p_key,0));
 if exists(select 1 from public.notifications where event_key='admin:'||p_key and (title is distinct from btrim(p_title) or body is distinct from p_body or actor_id is distinct from auth.uid())) then raise exception 'idempotency payload mismatch';end if;
 insert into public.notifications(user_id,category,title,body,actor_id,event_type,event_key)
 select id,'system',btrim(p_title),p_body,auth.uid(),'admin_announcement','admin:'||p_key from public.profiles where status='active'
 on conflict(user_id,event_key) where event_key is not null do nothing;
 get diagnostics total=row_count;
 return total;
end$$;
revoke all on function nimzo_private.send_admin_announcement(text,text,text) from public,anon;
grant execute on function nimzo_private.send_admin_announcement(text,text,text) to authenticated;
create function public.send_admin_announcement(p_title text,p_body text,p_key text) returns integer
language sql security invoker set search_path='' as $$select nimzo_private.send_admin_announcement(p_title,p_body,p_key)$$;
revoke all on function public.send_admin_announcement(text,text,text) from public,anon;
grant execute on function public.send_admin_announcement(text,text,text) to authenticated;
create function nimzo_private.notify_account_status() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.notifications(user_id,category,title,body,event_type)
 values(new.id,'system','Account status updated','Open NIMZO to review your account.','account_status');
 return new;
end$$;
revoke all on function nimzo_private.notify_account_status() from public,anon,authenticated;
create trigger notify_account_status after update of status on public.profiles for each row when(old.status is distinct from new.status) execute function nimzo_private.notify_account_status();
notify pgrst,'reload schema';

-- Restricted accounts cannot spend/convert; preserve approved1:1 rate.
CREATE OR REPLACE FUNCTION public.exchange_diamonds(p_amount bigint, p_key text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user uuid:=auth.uid();
  prior jsonb;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=v_user AND status='active') THEN
    RAISE EXCEPTION 'Active account required' USING ERRCODE='42501';
  END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_amount>9223372036854775807 THEN
    RAISE EXCEPTION 'invalid diamond exchange amount';
  END IF;
  IF nullif(trim(p_key),'') IS NULL OR length(p_key)>200 THEN
    RAISE EXCEPTION 'exchange idempotency key required';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('diamond_exchange:'||v_user::text||':'||p_key,0)
  );
  SELECT l.ref INTO prior FROM public.ledger l
    WHERE l.user_id=v_user AND l.kind='exchange' AND l.idempotency_key=p_key;
  IF FOUND THEN
    IF prior->>'amount' IS DISTINCT FROM p_amount::text THEN
      RAISE EXCEPTION 'exchange idempotency amount mismatch';
    END IF;
    RETURN;
  END IF;
  UPDATE public.wallets SET diamonds=diamonds-p_amount,coins=coins+p_amount
    WHERE user_id=v_user AND diamonds>=p_amount;
  IF NOT FOUND THEN RAISE EXCEPTION 'insufficient diamonds'; END IF;
  INSERT INTO public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  VALUES(v_user,'exchange',p_amount,-p_amount,
    jsonb_build_object('rate','1:1','amount',p_amount),p_key);
END;
$function$;

-- Preserve reseller limits; bind a retry key to actor, recipient and amount.
create index if not exists ledger_reseller_replay on public.ledger((ref->>'reseller'),idempotency_key) where kind='reseller';
create or replace function public.reseller_recharge(p_user uuid,p_coins bigint,p_key text) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); prior public.ledger%rowtype;
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and status='active') or not exists(select 1 from public.resellers where user_id=actor) then raise exception 'Active reseller required' using errcode='42501';end if;
 if p_user is null or p_coins is null or p_coins<=0 or nullif(btrim(p_key),'') is null or length(p_key)>200 then raise exception 'Invalid recharge request' using errcode='22023';end if;
 if not exists(select 1 from public.profiles where id=p_user and status='active') then raise exception 'user not found';end if;
 perform pg_advisory_xact_lock(hashtextextended('reseller:'||actor::text||':'||p_key,0));
 select * into prior from public.ledger where kind='reseller' and idempotency_key=p_key and ref->>'reseller'=actor::text limit 1;
 if found then
  if prior.user_id is distinct from p_user or prior.coin_delta is distinct from p_coins then raise exception 'idempotency payload mismatch';end if;
  return;
 end if;
 perform 1 from public.wallets where user_id=p_user for update;
 if not found then raise exception 'wallet missing';end if;
 update public.resellers set coin_limit=coin_limit-p_coins where user_id=actor and coin_limit>=p_coins;
 if not found then raise exception 'not a reseller or limit exceeded';end if;
 update public.wallets set coins=coins+p_coins where user_id=p_user;
 insert into public.ledger(user_id,kind,coin_delta,ref,idempotency_key) values(p_user,'reseller',p_coins,jsonb_build_object('reseller',actor),p_key);
end$$;
revoke all on function public.reseller_recharge(uuid,bigint,text) from public,anon;
grant execute on function public.reseller_recharge(uuid,bigint,text) to authenticated;
notify pgrst,'reload schema';

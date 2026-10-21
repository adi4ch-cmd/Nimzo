-- Secure server-authoritative coin purchases for new approved paid cosmetics.
-- Existing free claim/equip RPCs, wallet balances and ownership are preserved.
begin;

alter table public.nimzo_cosmetic_catalog
  drop constraint if exists nimzo_cosmetic_catalog_coin_price_check;
alter table public.nimzo_cosmetic_catalog
  add constraint nimzo_cosmetic_catalog_coin_price_check
  check (coin_price between 0 and 1000000000000);

create or replace function public.nimzo_store_purchase(
  p_item_id text,
  p_expected_price bigint,
  p_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_price bigint;
  v_ref jsonb;
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if p_item_id is null or char_length(p_item_id) not between 5 and 100
     or p_expected_price is null or p_expected_price <= 0
     or p_expected_price > 1000000000000
     or p_key is null or p_key !~ '^[a-f0-9]{32}$' then
    raise exception 'Invalid Store purchase request' using errcode='22023';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_user and p.status = 'active'
  ) then
    raise exception 'Account unavailable' using errcode='42501';
  end if;

  -- Per-account serialization protects retries using distinct keys too.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo-store:' || v_user::text, 0)
  );

  select l.ref into v_ref
  from public.ledger l
  where l.user_id = v_user
    and l.kind = 'store_purchase'
    and l.idempotency_key = 'nimzo-store:' || p_key;
  if found then
    if v_ref->>'item_id' is distinct from p_item_id
       or (v_ref->>'price')::bigint is distinct from p_expected_price then
      raise exception 'Idempotency payload mismatch' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object(
      'status', 'replayed', 'item_id', p_item_id, 'total', p_expected_price
    );
  end if;

  if exists (
    select 1 from public.nimzo_cosmetic_ownership o
    where o.user_id=v_user and o.item_id=p_item_id
  ) then
    return pg_catalog.jsonb_build_object(
      'status','already_owned','item_id',p_item_id,'total',0
    );
  end if;

  select c.coin_price into v_price
  from public.nimzo_cosmetic_catalog c
  where c.id=p_item_id and c.active
  for share;
  if v_price is null or v_price <= 0 then
    raise exception 'Paid item is not available' using errcode='22023';
  end if;
  if v_price != p_expected_price then
    raise exception 'Store price changed; refresh to confirm' using errcode='22023';
  end if;
  -- A chargeable cosmetic MUST have reviewed and playable remote artwork.
  if not exists (
    select 1 from public.nimzo_cosmetic_media m
    where m.item_id=p_item_id and m.approved and m.asset_url is not null
      and m.media_kind in ('image','svga','vap')
  ) then
    raise exception 'Item media not ready; no coins charged' using errcode='22023';
  end if;

  update public.wallets w
     set coins = w.coins - v_price
   where w.user_id = v_user and w.coins >= v_price;
  if not found then
    raise exception 'Insufficient coins; no purchase made' using errcode='22023';
  end if;

  insert into public.nimzo_cosmetic_ownership(user_id,item_id)
  values (v_user,p_item_id);

  insert into public.ledger (
    user_id,kind,coin_delta,diamond_delta,ref,idempotency_key
  ) values (
    v_user, 'store_purchase', -v_price, 0,
    pg_catalog.jsonb_build_object(
      'source','nimzo_dynamic_store','item_id',p_item_id,'price',v_price
    ),
    'nimzo-store:' || p_key
  );

  return pg_catalog.jsonb_build_object(
    'status','purchased','item_id',p_item_id,'total',v_price
  );
end;
$$;

revoke all on function public.nimzo_store_purchase(text,bigint,text)
  from public, anon, authenticated;
grant execute on function public.nimzo_store_purchase(text,bigint,text)
  to authenticated;
commit;

-- Optional, server-authoritative Store durations. NULL preserves every existing
-- lifetime item and ownership row; no catalog, balance or ownership backfill.
begin;
alter table public.nimzo_cosmetic_catalog
  add column if not exists duration_days integer;
alter table public.nimzo_cosmetic_ownership
  add column if not exists expires_at timestamptz;
alter table public.nimzo_cosmetic_catalog
  add constraint nimzo_cosmetic_duration_days_check
  check (duration_days is null or duration_days between 1 and 3650);

-- A non-charge result also needs a durable immutable receipt. Otherwise a lost
-- already-owned response could become a new charge after a later expiration.
create table nimzo_internal.store_no_charge_receipts (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_key text not null check(request_key ~ '^[a-f0-9]{32}$'),
  item_id text not null,
  expected_price bigint not null check(expected_price between 1 and 1000000000000),
  expires_at timestamptz,
  recorded_at timestamptz not null default now(),
  primary key(user_id,request_key)
);
alter table nimzo_internal.store_no_charge_receipts enable row level security;
revoke all on nimzo_internal.store_no_charge_receipts from public,anon,authenticated;

-- Read-only recovery is callable before client media preflight, so a successful
-- receipt remains recoverable when its original media/item has been withdrawn.
create or replace function public.store_purchase_receipt(
  p_item_id text,p_expected_price bigint,p_key text
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_user uuid := (select auth.uid()); v_ref jsonb; v_nocharge record;
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if p_item_id is null or char_length(p_item_id) not between 5 and 100
     or p_expected_price is null or p_expected_price<=0 or p_expected_price>1000000000000
     or p_key is null or p_key !~ '^[a-f0-9]{32}$' then
    raise exception 'Invalid Store purchase request' using errcode='22023';
  end if;
  select l.ref into v_ref from public.ledger l where l.user_id=v_user
    and l.kind='store_purchase' and l.idempotency_key='nimzo-store:'||p_key;
  if found then
    if v_ref->>'item_id' is distinct from p_item_id
      or (v_ref->>'price')::bigint is distinct from p_expected_price then
      raise exception 'Idempotency payload mismatch' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('status','replayed','item_id',p_item_id,
      'total',p_expected_price,'expires_at',v_ref->'expires_at');
  end if;
  select * into v_nocharge from nimzo_internal.store_no_charge_receipts r
    where r.user_id=v_user and r.request_key=p_key;
  if found then
    if v_nocharge.item_id is distinct from p_item_id
      or v_nocharge.expected_price is distinct from p_expected_price then
      raise exception 'Idempotency payload mismatch' using errcode='22023';
    end if;
    return pg_catalog.jsonb_build_object('status','already_owned','item_id',p_item_id,
      'total',0,'expires_at',v_nocharge.expires_at);
  end if;
  return null;
end;
$$;
revoke all on function public.store_purchase_receipt(text,bigint,text) from public,anon,authenticated;
grant execute on function public.store_purchase_receipt(text,bigint,text) to authenticated;

-- Own expired receipts remain readable for renewal/history; they are not usable
-- entitlements. Existing SELECT-only grants cover the additive expiry columns.
-- Hide expired equipment even from old clients that read this table directly.
drop policy if exists nimzo_cosmetics_equipped_view on public.nimzo_cosmetic_equipped;
create policy nimzo_cosmetics_equipped_view on public.nimzo_cosmetic_equipped
for select to authenticated using (
  user_id = (select auth.uid()) and exists (
    select 1 from public.nimzo_cosmetic_ownership o
    where o.user_id = nimzo_cosmetic_equipped.user_id
      and o.item_id = nimzo_cosmetic_equipped.item_id
      and (o.expires_at is null or o.expires_at > statement_timestamp())
  )
);

create or replace function public.nimzo_store_purchase(
  p_item_id text, p_expected_price bigint, p_key text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_price bigint;
  v_days integer;
  v_ref jsonb;
  v_now timestamptz;
  v_expiry timestamptz;
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
  -- Same account lock as the existing purchase RPC, also used by claim/equip.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo-store:' || v_user::text,0));
  v_now := clock_timestamp();

  -- Recover the original receipt before availability, expiry, price or media
  -- checks. A retry must never renew or charge again after the first expiry.
  v_ref := public.store_purchase_receipt(p_item_id,p_expected_price,p_key);
  if v_ref is not null then return v_ref; end if;

  if not exists (select 1 from public.profiles p
    where p.id=v_user and p.status='active') then
    raise exception 'Account unavailable' using errcode='42501';
  end if;

  select o.expires_at into v_expiry from public.nimzo_cosmetic_ownership o
    where o.user_id=v_user and o.item_id=p_item_id
      and (o.expires_at is null or o.expires_at>v_now) for update;
  if found then
    -- Early renewal is intentionally disabled: no charge, no duration change.
    insert into nimzo_internal.store_no_charge_receipts
      (user_id,request_key,item_id,expected_price,expires_at)
      values(v_user,p_key,p_item_id,p_expected_price,v_expiry);
    return pg_catalog.jsonb_build_object('status','already_owned',
      'item_id',p_item_id,'total',0,'expires_at',v_expiry);
  end if;

  select c.coin_price,c.duration_days into v_price,v_days
    from public.nimzo_cosmetic_catalog c where c.id=p_item_id and c.active for share;
  if v_price is null or v_price<=0 then
    raise exception 'Paid item is not available' using errcode='22023';
  end if;
  if v_price != p_expected_price then
    raise exception 'Store price changed; refresh to confirm' using errcode='22023';
  end if;
  if not exists (select 1 from public.nimzo_cosmetic_media m
    where m.item_id=p_item_id and m.approved and m.asset_url is not null
      and m.media_kind in ('image','svga','vap')) then
    raise exception 'Item media not ready; no coins charged' using errcode='22023';
  end if;
  -- Existing ledger publication guard verifies and locks immutable media inside
  -- this same transaction; failures roll back debit and renewed ownership.
  update public.wallets w set coins=w.coins-v_price
    where w.user_id=v_user and w.coins>=v_price;
  if not found then
    raise exception 'Insufficient coins; no purchase made' using errcode='22023';
  end if;
  v_expiry := case when v_days is null then null
    else v_now + pg_catalog.make_interval(days=>v_days) end;
  insert into public.nimzo_cosmetic_ownership(user_id,item_id,acquired_at,expires_at)
    values(v_user,p_item_id,v_now,v_expiry)
    on conflict(user_id,item_id) do update
      set acquired_at=excluded.acquired_at,expires_at=excluded.expires_at;
  insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
    values(v_user,'store_purchase',-v_price,0,
      pg_catalog.jsonb_build_object('source','nimzo_dynamic_store',
        'item_id',p_item_id,'price',v_price,'duration_days',v_days,
        'expires_at',v_expiry),'nimzo-store:' || p_key);
  return pg_catalog.jsonb_build_object('status','purchased','item_id',p_item_id,
    'total',v_price,'expires_at',v_expiry);
end;
$$;

create or replace function public.nimzo_store_claim_free(p_item_id text)
returns boolean language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_days integer;
  v_now timestamptz;
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if not exists(select 1 from public.profiles p where p.id=v_user and p.status='active') then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo-store:' || v_user::text,0));
  v_now := clock_timestamp();
  -- Lock current price: a concurrent price change cannot turn a paid item into
  -- a free claim. Existing active ownership is never shortened or extended.
  select c.duration_days into v_days from public.nimzo_cosmetic_catalog c
    where c.id=p_item_id and c.active and c.coin_price=0 for share;
  if not found then
    raise exception 'Free item not available' using errcode='22023';
  end if;
  insert into public.nimzo_cosmetic_ownership(user_id,item_id,acquired_at,expires_at)
    values(v_user,p_item_id,v_now,case when v_days is null then null
      else v_now + pg_catalog.make_interval(days=>v_days) end)
    on conflict(user_id,item_id) do update
      set acquired_at=excluded.acquired_at,expires_at=excluded.expires_at
      where nimzo_cosmetic_ownership.expires_at is not null
        and nimzo_cosmetic_ownership.expires_at<=v_now;
  return true;
end;
$$;

create or replace function public.nimzo_store_equip_free(p_item_id text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_user uuid := (select auth.uid()); v_category text;
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if not exists(select 1 from public.profiles p where p.id=v_user and p.status='active') then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo-store:' || v_user::text,0));
  select c.category into v_category from public.nimzo_cosmetic_catalog c
    join public.nimzo_cosmetic_ownership o on o.item_id=c.id
    where o.user_id=v_user and c.id=p_item_id and c.active
      and (o.expires_at is null or o.expires_at>clock_timestamp()) for share of c,o;
  if v_category is null then
    raise exception 'Item not owned or expired' using errcode='42501';
  end if;
  insert into public.nimzo_cosmetic_equipped(user_id,category,item_id,equipped_at)
    values(v_user,v_category,p_item_id,clock_timestamp())
    on conflict(user_id,category) do update
      set item_id=excluded.item_id,equipped_at=excluded.equipped_at;
  return true;
end;
$$;

-- Same public shape as the live function; never expose ownership/expiry of
-- other accounts. Consumers receive only currently usable visual equipment.
create or replace function public.nimzo_store_visual_equipment(p_user_ids uuid[])
returns table(user_id uuid,category text,item_id text)
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if not exists(select 1 from public.profiles p where p.id=v_user and p.status='active') then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  if pg_catalog.cardinality(p_user_ids)>100 then
    raise exception 'At most 100 users may be requested' using errcode='22023';
  end if;
  return query select e.user_id,e.category,e.item_id
    from public.nimzo_cosmetic_equipped e
    join public.nimzo_cosmetic_catalog c
      on c.id=e.item_id and c.category=e.category and c.active
    join public.nimzo_cosmetic_ownership o
      on o.user_id=e.user_id and o.item_id=e.item_id
        and (o.expires_at is null or o.expires_at>statement_timestamp())
    join public.profiles p on p.id=e.user_id and p.status='active'
    where e.user_id=any(p_user_ids);
end;
$$;

revoke all on function public.nimzo_store_purchase(text,bigint,text),
  public.nimzo_store_claim_free(text),public.nimzo_store_equip_free(text),
  public.nimzo_store_visual_equipment(uuid[]) from public,anon,authenticated;
grant execute on function public.nimzo_store_purchase(text,bigint,text),
  public.nimzo_store_claim_free(text),public.nimzo_store_equip_free(text),
  public.nimzo_store_visual_equipment(uuid[]) to authenticated;
commit;

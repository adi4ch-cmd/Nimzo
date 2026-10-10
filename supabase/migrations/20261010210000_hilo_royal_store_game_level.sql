-- NIMZO cosmetics and game-rank integration. Licensed art is bundled with the app.
-- Never import foreign accounts, foreign prices, balances, or credentials.
-- Existing user purchases, ledgers, memberships and gifts are preserved.

alter table public.profile_owned_collectibles
  add column if not exists equipped boolean not null default false;
create unique index if not exists nimzo_one_equipped_medal_per_user
  on public.profile_owned_collectibles (user_id) where equipped;

create table if not exists public.nimzo_store_catalog (
  collectible_id uuid primary key references public.profile_collectibles(id) on delete restrict,
  coin_price bigint not null check (coin_price > 0 and coin_price <= 1000000000),
  active boolean not null default true
);
alter table public.nimzo_store_catalog enable row level security;
revoke all on public.nimzo_store_catalog from public, anon, authenticated;
grant select on public.nimzo_store_catalog to authenticated;
drop policy if exists nimzo_store_catalog_view on public.nimzo_store_catalog;
create policy nimzo_store_catalog_view on public.nimzo_store_catalog
  for select to authenticated using (active);

insert into public.profile_collectibles (kind, name, image_path, description)
select 'medal', s.name, s.image_path, 'Permanent NIMZO Royal collectible. Equip from your Bag.'
from (values
 ('Royal Crest I','assets/hilo/store/royal_1.webp'),
 ('Royal Crest II','assets/hilo/store/royal_2.webp'),
 ('Royal Crest III','assets/hilo/store/royal_3.webp'),
 ('Royal Crest IV','assets/hilo/store/royal_4.webp'),
 ('Royal Crest V','assets/hilo/store/royal_5.webp'),
 ('Royal Crest VI','assets/hilo/store/royal_6.webp')
) as s(name,image_path)
where not exists (select 1 from public.profile_collectibles c where c.kind='medal' and c.name=s.name);

insert into public.nimzo_store_catalog (collectible_id, coin_price, active)
select c.id, s.price, true
from (values
 ('Royal Crest I',10000::bigint),
 ('Royal Crest II',25000::bigint),
 ('Royal Crest III',50000::bigint),
 ('Royal Crest IV',100000::bigint),
 ('Royal Crest V',250000::bigint),
 ('Royal Crest VI',500000::bigint)
) as s(name,price)
join public.profile_collectibles c on c.name=s.name and c.kind='medal'
on conflict (collectible_id) do nothing;

-- Every charge, ledger entry and ownership grant is one transaction. Lock wallet
-- before checking idempotency to serialize concurrent requests for this user.
create or replace function public.nimzo_store_buy(p_collectible uuid, p_request_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_price bigint;
  v_wallet bigint;
  v_entry public.ledger%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_request_key is null or p_request_key !~ '^[a-zA-Z0-9_-]{8,100}$' then
    raise exception 'Invalid purchase request';
  end if;
  select w.coins into v_wallet from public.wallets w where w.user_id=v_user for update;
  if not found then raise exception 'Wallet unavailable'; end if;
  select * into v_entry from public.ledger
    where user_id=v_user and idempotency_key='nimzo-store:'||p_request_key;
  if found then
    if v_entry.kind <> 'store_purchase'
       or v_entry.ref->>'collectible_id' <> p_collectible::text then
      raise exception 'Request key conflict';
    end if;
    return jsonb_build_object('purchased',true,'already_processed',true);
  end if;
  if not exists (select 1 from public.profiles where id=v_user and status='active') then
    raise exception 'Account unavailable';
  end if;
  select s.coin_price into v_price from public.nimzo_store_catalog s
  where s.collectible_id=p_collectible and s.active=true;
  if not found then raise exception 'Store item unavailable'; end if;
  if exists (select 1 from public.profile_owned_collectibles
    where user_id=v_user and collectible_id=p_collectible) then
    raise exception 'Already owned';
  end if;
  if v_wallet < v_price then raise exception 'Insufficient coins'; end if;
  update public.wallets set coins=coins-v_price where user_id=v_user;
  insert into public.profile_owned_collectibles (user_id,collectible_id)
    values (v_user,p_collectible);
  insert into public.ledger (user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
    values (v_user,'store_purchase',-v_price,0,
    jsonb_build_object('collectible_id',p_collectible), 'nimzo-store:'||p_request_key);
  return jsonb_build_object('purchased',true,'already_processed',false);
end;
$$;
revoke all on function public.nimzo_store_buy(uuid,text) from public, anon;
grant execute on function public.nimzo_store_buy(uuid,text) to authenticated;

-- Admin-awarded medals continue to work; users may equip only their own
-- unexpired item, and the operation never changes wallet or ownership.
create or replace function public.nimzo_store_equip(p_collectible uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.profile_owned_collectibles owned
    join public.profile_collectibles item on item.id=owned.collectible_id
    where owned.user_id=v_user and owned.collectible_id=p_collectible
      and item.kind='medal' and (owned.expires_at is null or owned.expires_at>now())
  ) then raise exception 'Medal unavailable'; end if;
  update public.profile_owned_collectibles set equipped=false
    where user_id=v_user and equipped=true;
  update public.profile_owned_collectibles set equipped=true
    where user_id=v_user and collectible_id=p_collectible;
  return true;
end;
$$;
revoke all on function public.nimzo_store_equip(uuid) from public, anon;
grant execute on function public.nimzo_store_equip(uuid) to authenticated;

-- Real levels: one credit per DISTINCT game round settled, with a won/lost bet.
-- Pending/refunded/aborted bets never grant game rank. No client-supplied XP.
create or replace function public.nimzo_game_level()
returns jsonb language sql stable security definer set search_path = '' as $$
with thresholds(level,need) as (values
  (0,0::bigint),(1,1),(2,3),(3,6),(4,10),(5,15),(6,21),
  (7,28),(8,36),(9,45),(10,55),(11,66),(12,78),(13,91),(14,105),(15,120)
), valid_rounds as (
  select count(distinct b.round_id)::bigint n
  from public.game_bets b
  join public.game_rounds r on r.id=b.round_id
  where b.user_id=(select auth.uid()) and b.status in ('won','lost') and r.status='settled'
), attained as (
  select max(t.level) as level from thresholds t cross join valid_rounds v where v.n>=t.need
)
select jsonb_build_object(
  'level',coalesce(a.level,0),
  'rounds_played',v.n,
  'next_rounds',(select min(t.need) from thresholds t where t.level>a.level)
) from valid_rounds v cross join attained a;
$$;
revoke all on function public.nimzo_game_level() from public, anon;
grant execute on function public.nimzo_game_level() to authenticated;

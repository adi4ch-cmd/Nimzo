-- Activate the Store using original NIMZO vector designs ONLY.
-- Third-party DangLive artwork / animations are not uploaded or distributed.
-- No wallet charges, ledger edits, legacy medal reactivation or VIP grants.
-- Free original cosmetic items are account-persistent and equipable.
begin;

create table if not exists public.nimzo_cosmetic_catalog (
  id text primary key check (char_length(id) between 5 and 100),
  category text not null check (category in (
    'Avatar Frame', 'Party Theme', 'Rides', 'Chat Bubble',
    'Live Frame', 'Royal Badge'
  )),
  name text not null,
  variant integer not null check (variant between 0 and 6),
  coin_price bigint not null default 0 check (coin_price = 0),
  active boolean not null default true
);

create table if not exists public.nimzo_cosmetic_ownership (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.nimzo_cosmetic_catalog(id)
    on delete restrict,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table if not exists public.nimzo_cosmetic_equipped (
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  item_id text not null,
  equipped_at timestamptz not null default now(),
  primary key (user_id, category),
  foreign key (user_id, item_id)
    references public.nimzo_cosmetic_ownership(user_id, item_id)
    on delete cascade
);

alter table public.nimzo_cosmetic_catalog enable row level security;
alter table public.nimzo_cosmetic_ownership enable row level security;
alter table public.nimzo_cosmetic_equipped enable row level security;

revoke all on public.nimzo_cosmetic_catalog from public, anon, authenticated;
revoke all on public.nimzo_cosmetic_ownership from public, anon, authenticated;
revoke all on public.nimzo_cosmetic_equipped from public, anon, authenticated;

grant select on public.nimzo_cosmetic_catalog to authenticated;
grant select on public.nimzo_cosmetic_ownership to authenticated;
grant select on public.nimzo_cosmetic_equipped to authenticated;

drop policy if exists nimzo_cosmetics_catalog_view
  on public.nimzo_cosmetic_catalog;
create policy nimzo_cosmetics_catalog_view
  on public.nimzo_cosmetic_catalog
  for select to authenticated using (active = true);

drop policy if exists nimzo_cosmetics_owned_view
  on public.nimzo_cosmetic_ownership;
create policy nimzo_cosmetics_owned_view
  on public.nimzo_cosmetic_ownership
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists nimzo_cosmetics_equipped_view
  on public.nimzo_cosmetic_equipped;
create policy nimzo_cosmetics_equipped_view
  on public.nimzo_cosmetic_equipped
  for select to authenticated using (user_id = (select auth.uid()));

with categories(category,slug) as (values
  ('Avatar Frame','avatar-frame'),
  ('Party Theme','party-theme'),
  ('Rides','rides'),
  ('Chat Bubble','chat-bubble'),
  ('Live Frame','live-frame'),
  ('Royal Badge','royal-badge')
), styles(name,slug,variant) as (values
  ('Golden Stars','golden-stars',0),
  ('Kiss Me','kiss-me',1),
  ('Cherry Blossom','cherry-blossom',2),
  ('Neon','neon',3),
  ('Floral','floral',4),
  ('Hearts','hearts',5),
  ('Royal','royal',6)
)
insert into public.nimzo_cosmetic_catalog
  (id,category,name,variant,coin_price,active)
select 'nimzo-original-' || c.slug || '-' || s.slug,
       c.category,s.name,s.variant,0,true
from categories c cross join styles s
on conflict (id) do nothing;

create or replace function public.nimzo_store_claim_free(p_item_id text)
returns boolean language plpgsql security definer
set search_path = '' as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id=v_user and p.status='active'
  ) then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  if not exists (
    select 1 from public.nimzo_cosmetic_catalog c
    where c.id=p_item_id and c.active and c.coin_price=0
  ) then
    raise exception 'Free item not available' using errcode='22023';
  end if;
  insert into public.nimzo_cosmetic_ownership(user_id,item_id)
  values (v_user,p_item_id)
  on conflict (user_id,item_id) do nothing;
  return true;
end;
$$;

create or replace function public.nimzo_store_equip_free(p_item_id text)
returns boolean language plpgsql security definer
set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_category text;
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode='28000';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id=v_user and p.status='active'
  ) then
    raise exception 'Account unavailable' using errcode='42501';
  end if;
  select c.category into v_category
  from public.nimzo_cosmetic_catalog c
  join public.nimzo_cosmetic_ownership o on o.item_id=c.id
  where o.user_id=v_user and c.id=p_item_id and c.active;
  if v_category is null then
    raise exception 'Item not owned' using errcode='42501';
  end if;
  insert into public.nimzo_cosmetic_equipped
    (user_id,category,item_id,equipped_at)
  values (v_user,v_category,p_item_id,now())
  on conflict (user_id,category) do update
    set item_id=excluded.item_id,equipped_at=excluded.equipped_at;
  return true;
end;
$$;

revoke all on function public.nimzo_store_claim_free(text)
  from public,anon,authenticated;
revoke all on function public.nimzo_store_equip_free(text)
  from public,anon,authenticated;
grant execute on function public.nimzo_store_claim_free(text)
  to authenticated;
grant execute on function public.nimzo_store_equip_free(text)
  to authenticated;

commit;

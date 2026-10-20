-- Extend appearance categories without rewriting legacy catalog IDs or ownership.
-- Local media is selected by the app's pinned ID registry, never user metadata.
-- No prices, wallets, ledgers, profiles, or legacy equipment are rewritten.
begin;

alter table public.nimzo_cosmetic_catalog
  drop constraint nimzo_cosmetic_catalog_category_check;
alter table public.nimzo_cosmetic_catalog
  add constraint nimzo_cosmetic_catalog_category_check check (category in (
    'Avatar Frame', 'Party Theme', 'Rides', 'Chat Bubble',
    'Live Frame', 'Royal Badge', 'Mic Wave', 'Profile Card', 'ID Frame'
  ));

-- SECURITY DEFINER is needed for this narrow cross-user projection because
-- equipped and ownership tables deliberately retain their own-user SELECT RLS.
-- No inventory, acquisition time, wallet, or editable profile metadata is exposed.
create or replace function public.nimzo_store_visual_equipment(p_user_ids uuid[])
returns table (user_id uuid, category text, item_id text)
language plpgsql stable security definer
set search_path = '' as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = v_user and p.status = 'active'
  ) then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;
  if pg_catalog.cardinality(p_user_ids) > 100 then
    raise exception 'At most 100 users may be requested' using errcode = '22023';
  end if;
  return query
    select e.user_id, e.category, e.item_id
    from public.nimzo_cosmetic_equipped e
    join public.nimzo_cosmetic_catalog c
      on c.id = e.item_id and c.category = e.category and c.active
    join public.nimzo_cosmetic_ownership o
      on o.user_id = e.user_id and o.item_id = e.item_id
    join public.profiles p on p.id = e.user_id and p.status = 'active'
    where e.user_id = any(p_user_ids);
end;
$$;

create or replace function public.nimzo_store_unequip(p_category text)
returns boolean language plpgsql security definer
set search_path = '' as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = v_user and p.status = 'active'
  ) then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;
  if p_category is null or p_category not in (
    'Avatar Frame', 'Party Theme', 'Rides', 'Chat Bubble',
    'Live Frame', 'Royal Badge', 'Mic Wave', 'Profile Card', 'ID Frame'
  ) then
    raise exception 'Unknown cosmetic category' using errcode = '22023';
  end if;
  -- Clients have SELECT only; this function is the sole new write capability.
  delete from public.nimzo_cosmetic_equipped e
  where e.user_id = v_user and e.category = p_category;
  return true;
end;
$$;

revoke all on function public.nimzo_store_visual_equipment(uuid[])
  from public, anon, authenticated;
revoke all on function public.nimzo_store_unequip(text)
  from public, anon, authenticated;
grant execute on function public.nimzo_store_visual_equipment(uuid[])
  to authenticated;
grant execute on function public.nimzo_store_unequip(text)
  to authenticated;

commit;

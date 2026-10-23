-- Additive selection only. No grants of membership or changes to user economy.
begin;
set local lock_timeout='10s';
create schema if not exists nimzo_internal;
create table public.nimzo_membership_equipment(
 user_id uuid primary key references public.profiles(id) on delete cascade,
 kind text check(kind in ('vip','svip')),
 tier integer check(tier between 1 and 10),
 disabled_slots text[] not null default '{}',
 updated_at timestamptz not null default clock_timestamp(),
 check ((kind is null)=(tier is null)),
 check (disabled_slots <@ array['Avatar Frame','Rides','Chat Bubble','Mic Wave','Profile Card','Profile Decoration','ID Frame','Royal Badge','Room Header']::text[])
);
alter table public.nimzo_membership_equipment enable row level security;
revoke all on public.nimzo_membership_equipment from public,anon,authenticated;
grant select on public.nimzo_membership_equipment to authenticated;
create policy membership_visual_selection_read on public.nimzo_membership_equipment
 for select to authenticated using ((select auth.uid()) is not null);

-- Only sanitized effective state is used by renderers. A selected expired pack
-- stays dormant; another membership is not silently applied in its place.
create function public.nimzo_membership_appearance(p_user uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 with membership as (select public.phoenix_membership(p_user) as m),
 selected as (
  select e.* from public.nimzo_membership_equipment e, membership s
  where e.user_id=p_user and e.kind is not null and
   (s.m->>(e.kind||'_level'))::integer=e.tier
 ), identity as (
  select s.m,e.kind,e.tier,e.disabled_slots,
   coalesce(e.kind,case when (s.m->>'svip_level')::integer>0 then 'svip'
    when (s.m->>'vip_level')::integer>0 then 'vip' end) as primary_kind
  from membership s left join selected e on true
 )
 select m || jsonb_build_object(
  'primary_kind',primary_kind,
  'primary_tier',case when primary_kind is null then 0 else (m->>(primary_kind||'_level'))::integer end,
  'pack_kind',kind,'pack_tier',coalesce(tier,0),
  'pack_expires_at',case when kind is null then null else m->>(kind||'_expires_at') end,
  'pack_slots',case when kind is null then '[]'::jsonb else
    to_jsonb(array(select s from unnest(array['Avatar Frame','Rides','Chat Bubble','Mic Wave','Profile Card','Profile Decoration','ID Frame','Royal Badge','Room Header']) s
     where not (s=any(disabled_slots)))) end)
 from identity where auth.uid() is not null;
$$;

create function public.nimzo_membership_apply_full_set(p_kind text,p_tier integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=(select auth.uid());
begin
 if u is null then raise exception 'Sign in required' using errcode='28000'; end if;
 if p_kind is null or p_kind not in ('vip','svip') or p_tier is null or p_tier not between 1 and 10 then
  raise exception 'Invalid membership kind or tier' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('nimzo-store:'||u::text,0));
 perform 1 from public.profiles where id=u and status='active' for update;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 if not exists(select 1 from public.profiles p where p.id=u and p.status='active' and
   ((p_kind='vip' and p.vip_level=p_tier and p.vip_expires_at>clock_timestamp()) or
    (p_kind='svip' and p.svip_level=p_tier and p.svip_cycle_start+interval '90 days'>clock_timestamp()))) then
  raise exception 'This exact membership is inactive or expired' using errcode='42501'; end if;
 insert into public.nimzo_membership_equipment(user_id,kind,tier,disabled_slots)
 values(u,p_kind,p_tier,'{}') on conflict(user_id) do update
 set kind=excluded.kind,tier=excluded.tier,disabled_slots='{}',updated_at=clock_timestamp();
 return public.nimzo_membership_appearance(u);
end $$;

create function public.nimzo_membership_remove_full_set()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=(select auth.uid());
begin
 if u is null then raise exception 'Sign in required' using errcode='28000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('nimzo-store:'||u::text,0));
 update public.nimzo_membership_equipment set kind=null,tier=null,disabled_slots='{}',updated_at=clock_timestamp() where user_id=u;
 return public.nimzo_membership_appearance(u);
end $$;

-- Existing Store RPCs remain the only way to equip owned items. Their successful
-- insert/update disables just that pack slot, in the same transaction.
create function nimzo_internal.membership_manual_equipment_override()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.category='Party Theme' then
  update public.nimzo_membership_room_background set kind=null,tier=null,updated_at=clock_timestamp() where owner_id=new.user_id and kind is not null;
 end if;
 update public.nimzo_membership_equipment set
 disabled_slots=array(select distinct s from unnest(disabled_slots||new.category) s),
 updated_at=clock_timestamp()
 where user_id=new.user_id and kind is not null
 and new.category=any(array['Avatar Frame','Rides','Chat Bubble','Mic Wave','Profile Card','Profile Decoration','ID Frame','Royal Badge','Room Header']);
 return new;
end $$;
revoke all on function nimzo_internal.membership_manual_equipment_override() from public,anon,authenticated;
create trigger membership_manual_equipment_override after insert or update
 on public.nimzo_cosmetic_equipped for each row execute function nimzo_internal.membership_manual_equipment_override();

-- Membership wallpapers require an explicit room-owner action, independently
-- of full-pack apply. This row never changes rooms/backgrounds or Store items.
create table public.nimzo_membership_room_background(
 room_id uuid primary key references public.rooms(id) on delete cascade,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 kind text check(kind in ('vip','svip')),tier integer check(tier between 1 and 10),
 updated_at timestamptz not null default clock_timestamp(),
 check((kind is null)=(tier is null))
);
create index nimzo_membership_room_background_owner_idx on public.nimzo_membership_room_background(owner_id);
alter table public.nimzo_membership_room_background enable row level security;
revoke all on public.nimzo_membership_room_background from public,anon,authenticated;
grant select on public.nimzo_membership_room_background to authenticated;
create policy membership_room_background_read on public.nimzo_membership_room_background
 for select to authenticated using ((select auth.uid()) is not null);

create function public.nimzo_membership_set_room_background(p_room uuid,p_apply boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=(select auth.uid()); a jsonb;
begin
 if u is null then raise exception 'Sign in required' using errcode='28000'; end if;
 perform pg_advisory_xact_lock(hashtextextended('nimzo-store:'||u::text,0));
 perform 1 from public.rooms where id=p_room and owner_id=u for update;
 if not found then raise exception 'Only the room owner may change its membership background' using errcode='42501'; end if;
 a:=public.nimzo_membership_appearance(u);
 -- Only currently inventoried genuine room wallpaper. Extend after provenance audit.
 if p_apply and not (a->>'pack_kind'='vip' and a->>'pack_tier'='6') then
  raise exception 'This pack has no verified room wallpaper' using errcode='22023'; end if;
 insert into public.nimzo_membership_room_background(room_id,owner_id,kind,tier)
 values(p_room,u,case when p_apply then a->>'pack_kind' end,case when p_apply then (a->>'pack_tier')::integer end)
 on conflict(room_id) do update set owner_id=u,kind=excluded.kind,tier=excluded.tier,updated_at=clock_timestamp();
 return true;
end $$;

create function public.nimzo_membership_room_appearance(p_room uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('kind',b.kind,'tier',b.tier)
 from public.nimzo_membership_room_background b join public.rooms r on r.id=b.room_id and r.owner_id=b.owner_id
 cross join lateral public.nimzo_membership_appearance(b.owner_id) a
 where b.room_id=p_room and b.kind=a->>'pack_kind' and b.tier=(a->>'pack_tier')::integer
 and auth.uid() is not null;
$$;

revoke all on function public.nimzo_membership_appearance(uuid),public.nimzo_membership_apply_full_set(text,integer),
 public.nimzo_membership_remove_full_set(),public.nimzo_membership_set_room_background(uuid,boolean),
 public.nimzo_membership_room_appearance(uuid) from public,anon,authenticated;
grant execute on function public.nimzo_membership_appearance(uuid),public.nimzo_membership_apply_full_set(text,integer),
 public.nimzo_membership_remove_full_set(),public.nimzo_membership_set_room_background(uuid,boolean),
 public.nimzo_membership_room_appearance(uuid) to authenticated;

do $$ declare t text; begin
 foreach t in array array['nimzo_membership_equipment','nimzo_membership_room_background'] loop
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
   execute format('alter publication supabase_realtime add table public.%I',t);
  end if;
 end loop;
end $$;
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
    where e.user_id=any(p_user_ids)
      and not (coalesce(public.nimzo_membership_appearance(e.user_id)->'pack_slots','[]'::jsonb) ? e.category);
end;
$$;
notify pgrst,'reload schema';
commit;

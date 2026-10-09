-- Display entitlement only. Purchases, gifts and rewards keep existing authorization.
create or replace function public.phoenix_membership(p_user uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
 select jsonb_build_object(
   'vip_level', case when p.status='active' and p.vip_expires_at>now()
     then coalesce(p.vip_level,0) else 0 end,
   'vip_expires_at',p.vip_expires_at,'server_now',now())
 from public.profiles p where p.id=p_user and auth.uid() is not null;
$$;
revoke all on function public.phoenix_membership(uuid) from public,anon;
grant execute on function public.phoenix_membership(uuid) to authenticated;

create table public.phoenix_room_entries (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.rooms(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 display_name text not null,
 created_at timestamptz not null default now()
);
create index phoenix_entries_room_time on public.phoenix_room_entries(room_id,created_at desc);
alter table public.phoenix_room_entries enable row level security;
revoke all on public.phoenix_room_entries from public,anon,authenticated;
grant select on public.phoenix_room_entries to authenticated;
create policy phoenix_entries_joined on public.phoenix_room_entries
 for select to authenticated using (exists (
   select 1 from public.room_members m where m.room_id=phoenix_room_entries.room_id
     and m.user_id=(select auth.uid()) and m.joined_at<=phoenix_room_entries.created_at
 ));

-- Private trigger is the only writer; ON CONFLICT duplicate joins never emit an event.
create or replace function nimzo_private.phoenix_room_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.phoenix_room_entries(room_id,user_id,display_name)
 select new.room_id,p.id,coalesce(nullif(p.display_name,''),nullif(p.username,''),'Nimzo user')
 from public.profiles p where p.id=new.user_id and p.status='active'
   and p.vip_level=6 and p.vip_expires_at>now();
 return new;
end;
$$;
revoke all on function nimzo_private.phoenix_room_entry() from public,anon,authenticated;
create trigger phoenix_room_entry after insert on public.room_members
 for each row execute function nimzo_private.phoenix_room_entry();

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
   and schemaname='public' and tablename='phoenix_room_entries') then
 alter publication supabase_realtime add table public.phoenix_room_entries;
 end if;
end $$;

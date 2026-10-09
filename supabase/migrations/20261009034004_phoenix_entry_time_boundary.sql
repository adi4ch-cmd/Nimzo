-- Room visit tracking stamps joined_at with wall time, not transaction start.
-- Use that exact boundary so the entry is visible under its member-only RLS.
alter table public.phoenix_room_entries alter column created_at set default clock_timestamp();
create or replace function nimzo_private.phoenix_room_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.phoenix_room_entries(room_id,user_id,display_name,created_at)
 select new.room_id,p.id,coalesce(nullif(p.display_name,''),nullif(p.username,''),'Nimzo user'),new.joined_at
 from public.profiles p where p.id=new.user_id and p.status='active'
   and p.vip_level=6 and p.vip_expires_at>clock_timestamp();
 return new;
end;
$$;
revoke all on function nimzo_private.phoenix_room_entry() from public,anon,authenticated;

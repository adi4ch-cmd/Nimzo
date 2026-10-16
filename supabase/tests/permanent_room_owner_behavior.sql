-- Disposable metadata clone only. Production verification uses the read-only
-- one_room_per_user.sql instead. No production account fixtures are created.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000901','room-guard-one@example.invalid'),
 ('00000000-0000-4000-8000-000000000902','room-guard-two@example.invalid');
insert into public.profiles(id) values
 ('00000000-0000-4000-8000-000000000901'),
 ('00000000-0000-4000-8000-000000000902');
insert into public.rooms(owner_id,name,status) values
 ('00000000-0000-4000-8000-000000000901','Permanent closed room','closed');
do $$
begin
  begin
    insert into public.rooms(owner_id,name) values
     ('00000000-0000-4000-8000-000000000901','Duplicate open room');
    raise exception 'Second room accepted for a closed-room owner';
  exception when unique_violation then null;
  end;
  if exists(select 1 from public.rooms r join public.profiles p on p.id=r.owner_id
            where r.room_no is distinct from p.nimzo_id) then
    raise exception 'Omitted room number did not use permanent Nimzo ID';
  end if;
end $$;
insert into public.rooms(owner_id,name,room_no) values
 ('00000000-0000-4000-8000-000000000902','Second owner',999999999);
update public.rooms set room_no=999999999 where owner_id='00000000-0000-4000-8000-000000000902';
do $$
begin
 if exists(select 1 from public.rooms r join public.profiles p on p.id=r.owner_id
           where r.room_no is distinct from p.nimzo_id) then
   raise exception 'Explicit insert/update changed permanent room number';
 end if;
 if has_function_privilege('anon','nimzo_private.enforce_owner_room_number()','execute')
    or has_function_privilege('authenticated','nimzo_private.enforce_owner_room_number()','execute') then
   raise exception 'Private room trigger exposed as an RPC';
 end if;
end $$;
rollback;

-- Execute in a disposable schema-only clone. All fixtures roll back.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000911','settings-owner@example.invalid'),
 ('00000000-0000-4000-8000-000000000912','settings-outsider@example.invalid');
insert into public.profiles(id) values
 ('00000000-0000-4000-8000-000000000911'),
 ('00000000-0000-4000-8000-000000000912');
insert into public.rooms(id,owner_id,name,avatar_path) values
 ('00000000-0000-4000-8000-000000000913','00000000-0000-4000-8000-000000000911','Original room','original.jpg');
create function pg_temp.reject_test_photo() returns trigger language plpgsql as $$
begin
 if new.avatar_path='broken.jpg' then raise exception 'photo write failed' using errcode='23514'; end if;
 return new;
end $$;
create trigger test_photo_failure before update of avatar_path on public.rooms
 for each row execute function pg_temp.reject_test_photo();
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000911';
set local role authenticated;
do $$
begin
 begin
  perform public.save_room_settings('00000000-0000-4000-8000-000000000913','Partial room','sage',true,'newpassword',false,true,true,true,true,true,true,'broken.jpg');
  raise exception 'Expected injected photo failure';
 exception when check_violation then null;
 end;
end $$;
reset role;
do $$
begin
 if not exists(select 1 from public.rooms where id='00000000-0000-4000-8000-000000000913'
  and name='Original room' and avatar_path='original.jpg' and not is_private and password_hash is null and perm_mic) then
  raise exception 'Settings partially committed after photo failure';
 end if;
end $$;
set local role authenticated;
select public.save_room_settings('00000000-0000-4000-8000-000000000913','Saved room','sage',true,'newpassword',false,true,true,true,true,true,true,'saved.jpg');
reset role;
do $$
begin
 if not exists(select 1 from public.rooms where id='00000000-0000-4000-8000-000000000913'
   and name='Saved room' and avatar_path='saved.jpg' and is_private and not perm_mic
   and password_hash=extensions.crypt('newpassword',password_hash) and password_hash<>'newpassword') then
  raise exception 'Atomic save did not preserve settings or password hashing';
 end if;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000912';
set local role authenticated;
do $$
begin
 begin
  perform public.save_room_settings('00000000-0000-4000-8000-000000000913','Unauthorized','sage',false,null,true,true,true,true,true,true,true,null);
  raise exception 'Unauthorized settings write accepted';
 exception when raise_exception then
  if sqlerrm<>'only the owner can change settings' then raise; end if;
 end;
end $$;
reset role;
do $$
begin
 if has_function_privilege('anon','public.save_room_settings(uuid,text,text,boolean,text,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text)','execute') then
   raise exception 'Anonymous save RPC access';
 end if;
 if exists(select 1 from public.rooms where name='Unauthorized') then raise exception 'Outsider changed settings'; end if;
end $$;
rollback;

begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000801','owner@test.invalid'),
 ('00000000-0000-4000-8000-000000000802','member@test.invalid'),
 ('00000000-0000-4000-8000-000000000803','mod@test.invalid'),
 ('00000000-0000-4000-8000-000000000804','protected@test.invalid'),
 ('00000000-0000-4000-8000-000000000805','admin@test.invalid');
insert into public.rooms(id,room_no,owner_id,name) values('00000000-0000-4000-8000-000000000811',(select nimzo_id from public.profiles where id='00000000-0000-4000-8000-000000000801'),'00000000-0000-4000-8000-000000000801','Moderation fixture');
insert into public.room_members(room_id,user_id) values
 ('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000802'),
 ('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000804');
update public.mic_seats set user_id='00000000-0000-4000-8000-000000000802' where room_id='00000000-0000-4000-8000-000000000811' and seat_no=1;
insert into public.room_moderators(room_id,user_id) values('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000803');
insert into public.admins(user_id) values('00000000-0000-4000-8000-000000000805');
update public.profiles set svip_level=5 where id='00000000-0000-4000-8000-000000000804';
set local role authenticated;
set local request.jwt.claim.sub='';
do $$ begin
 begin perform public.get_room_moderation('00000000-0000-4000-8000-000000000811'); raise exception 'FAIL unauth capability'; exception when invalid_authorization_specification then null; end;
 begin perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000802',false); raise exception 'FAIL unauth action'; exception when invalid_authorization_specification then null; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000802';
do $$ begin
 if public.get_room_moderation('00000000-0000-4000-8000-000000000811') then raise exception 'nonmoderator capability'; end if;
 begin perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000804',true); raise exception 'FAIL nonmoderator action'; exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000801';
do $$ begin
 if not public.get_room_moderation('00000000-0000-4000-8000-000000000811') then raise exception 'owner capability'; end if;
 begin perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000804',false); raise exception 'FAIL SVIP protection'; exception when insufficient_privilege then null; end;
 begin perform public.moderate_room_member('00000000-0000-4000-8000-000000000811',auth.uid(),true); raise exception 'FAIL owner self removal'; exception when insufficient_privilege then null; end;
 perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000802',false);
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.room_members where user_id='00000000-0000-4000-8000-000000000802') or exists(select 1 from public.mic_seats where user_id='00000000-0000-4000-8000-000000000802') or exists(select 1 from public.room_bans where user_id='00000000-0000-4000-8000-000000000802') then raise exception 'kick cleanup or temporary semantics'; end if;
 if not exists(select 1 from public.room_members where user_id='00000000-0000-4000-8000-000000000804') then raise exception 'untargeted member changed'; end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000802';
select public.join_room('00000000-0000-4000-8000-000000000811');
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000803';
do $$ begin
 if not public.get_room_moderation('00000000-0000-4000-8000-000000000811') then raise exception 'room moderator capability'; end if;
 perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000802',true);
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000802';
do $$ begin
 begin perform public.join_room('00000000-0000-4000-8000-000000000811'); raise exception 'FAIL banned user rejoined';
 exception when raise_exception then if sqlerrm not in ('banned from room') then raise; end if; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000805';
do $$ begin
 if not public.get_room_moderation('00000000-0000-4000-8000-000000000811') then raise exception 'admin capability'; end if;
 begin perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000801',true); raise exception 'FAIL admin removed owner'; exception when insufficient_privilege then null; end;
 perform public.moderate_room_member('00000000-0000-4000-8000-000000000811','00000000-0000-4000-8000-000000000804',false);
end $$;
reset role;
do $$ begin
 if not exists(select 1 from public.room_bans where user_id='00000000-0000-4000-8000-000000000802') then raise exception 'ban missing'; end if;
 if exists(select 1 from public.room_members where user_id='00000000-0000-4000-8000-000000000804') or exists(select 1 from public.room_bans where user_id='00000000-0000-4000-8000-000000000804') then raise exception 'admin protected kick semantics'; end if;
 if not exists(select 1 from public.rooms where owner_id='00000000-0000-4000-8000-000000000801') then raise exception 'room owner changed'; end if;
end $$;
select 'PASS room moderation auth, owner/mod/admin authority, protected target, kick rejoin, permanent ban, owner safety';
rollback;

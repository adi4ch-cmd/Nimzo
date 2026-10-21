-- Run against a disposable database after room_fifteen_mic_seats migration.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000001501','seat-owner@test.invalid'),
 ('00000000-0000-4000-8000-000000001502','seat-member@test.invalid'),
 ('00000000-0000-4000-8000-000000001503','seat-mod@test.invalid');
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000001501';
select public.create_room('Fifteen seat fixture',null,null) as room_id \gset
reset role;
insert into public.room_members(room_id,user_id) values
 (:'room_id','00000000-0000-4000-8000-000000001502'),
 (:'room_id','00000000-0000-4000-8000-000000001503');
insert into public.room_moderators(room_id,user_id) values
 (:'room_id','00000000-0000-4000-8000-000000001503');
select set_config('seat_test.room', :'room_id',true);
do $$ begin
 if (select count(*) from public.mic_seats where room_id=current_setting('seat_test.room')::uuid)<>15 then raise exception 'FAIL new room requires 15 seats'; end if;
 begin insert into public.mic_seats(room_id,seat_no) values(current_setting('seat_test.room')::uuid,16); raise exception 'FAIL seat 16 allowed'; exception when check_violation then null; end;
 begin insert into public.mic_seats(room_id,seat_no) values(current_setting('seat_test.room')::uuid,0); raise exception 'FAIL seat zero allowed'; exception when check_violation then null; end;
end $$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000001502';
select public.take_seat(:'room_id',15);
do $$ begin
 begin perform public.take_seat(current_setting('seat_test.room')::uuid,16); raise exception 'FAIL seat 16 RPC allowed'; exception when raise_exception then if sqlerrm<>'bad seat' then raise; end if; end;
 begin perform public.mod_lock_seat(current_setting('seat_test.room')::uuid,14,true); raise exception 'FAIL member locked seat'; exception when insufficient_privilege then null; end;
 begin perform public.mod_assign_seat(current_setting('seat_test.room')::uuid,14,auth.uid()); raise exception 'FAIL member assigned seat'; exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000001503';
select public.mod_lock_seat(:'room_id',14,true);
select public.mod_mute_seat(:'room_id',15,true);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000001501';
do $$ begin
 begin perform public.mod_assign_seat(current_setting('seat_test.room')::uuid,15,auth.uid()); raise exception 'FAIL occupied seat overwritten'; exception when raise_exception then if sqlerrm<>'seat unavailable' then raise; end if; end;
 begin perform public.mod_assign_seat(current_setting('seat_test.room')::uuid,14,'00000000-0000-4000-8000-000000001502'); raise exception 'FAIL assignment bypassed lock'; exception when raise_exception then if sqlerrm<>'seat unavailable' then raise; end if; end;
 begin perform public.take_seat(current_setting('seat_test.room')::uuid,14); raise exception 'FAIL locked seat allowed'; exception when raise_exception then if sqlerrm<>'seat unavailable' then raise; end if; end;
end $$;
select public.mod_lock_seat(:'room_id',14,false);
select public.mod_assign_seat(:'room_id',14,'00000000-0000-4000-8000-000000001502');
reset role;
do $$ begin
 if not exists(select 1 from public.mic_seats where room_id=current_setting('seat_test.room')::uuid and seat_no=14 and user_id='00000000-0000-4000-8000-000000001502') then raise exception 'FAIL assignment'; end if;
 if exists(select 1 from public.mic_seats where room_id=current_setting('seat_test.room')::uuid and seat_no=15 and user_id is not null) then raise exception 'FAIL previous seat retained'; end if;
end $$;
do $$ begin
 if has_function_privilege('anon','public.mod_lock_seat(uuid,integer,boolean)','execute') or has_function_privilege('anon','public.mod_assign_seat(uuid,integer,uuid)','execute') then raise exception 'FAIL anonymous controls exposed'; end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub='';
do $$ begin
 begin perform public.mod_lock_seat(current_setting('seat_test.room')::uuid,1,true); raise exception 'FAIL unauthenticated lock'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;
select 'PASS 15-seat creation, bounds, seating, moderator lock/mute, owner assignment';
rollback;

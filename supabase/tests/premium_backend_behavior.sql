-- Execute inside BEGIN; rollback at caller. Never commit these transaction-only fixtures.
-- First assertion is the pre-repair regression: protected UPDATE currently succeeds.
do $$ begin if has_column_privilege('authenticated','public.profiles','vip_level','UPDATE') then raise exception 'REGRESSION: client can edit VIP'; end if; end $$;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000101','nimzo-repair-owner@example.invalid'),('00000000-0000-4000-8000-000000000102','nimzo-repair-member@example.invalid'),('00000000-0000-4000-8000-000000000103','nimzo-repair-outsider@example.invalid');
insert into public.rooms(id,room_no,owner_id,name,game_permission) values('00000000-0000-4000-8000-000000000201',999999900001,'00000000-0000-4000-8000-000000000101','Repair transaction fixture','members');
insert into public.room_members(room_id,user_id,role) values('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000102','moderator');
insert into public.room_moderators values('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000102');
insert into public.mic_seats(room_id,seat_no) values('00000000-0000-4000-8000-000000000201',1),('00000000-0000-4000-8000-000000000201',2);
insert into public.room_messages(room_id,user_id,body) values('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000102','Ephemeral fixture');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
set local role authenticated;
do $$ declare v jsonb; begin
 update profiles set bio='Safe edit works' where id=auth.uid();
 begin update profiles set vip_level=5 where id=auth.uid(); raise exception 'VIP update unexpectedly allowed'; exception when insufficient_privilege then null; end;
 begin select password_hash from rooms limit 1; raise exception 'Password read unexpectedly allowed'; exception when insufficient_privilege then null; end;
 perform id from rooms_ranked limit 1;
 begin insert into rooms(room_no,owner_id,name) values(999999900002,auth.uid(),'Bypass'); raise exception 'Direct room creation unexpectedly allowed'; exception when insufficient_privilege then null; end;
 begin insert into profile_tags(user_id,tag) values(auth.uid(),'Verified'); raise exception 'Tag forgery unexpectedly allowed'; exception when insufficient_privilege then null; end;
 perform take_seat('00000000-0000-4000-8000-000000000201',1);
 begin perform take_seat('00000000-0000-4000-8000-000000000201',2); raise exception 'Second seat unexpectedly allowed'; exception when raise_exception then if sqlerrm<>'already seated' then raise; end if; end;
 if reconcile_wallet('00000000-0000-4000-8000-000000000101') is not null then raise exception 'Other wallet leaked'; end if;
 perform leave_room('00000000-0000-4000-8000-000000000201');
 if exists(select 1 from room_members where user_id=auth.uid()) or exists(select 1 from mic_seats where user_id=auth.uid()) then raise exception 'Moderator left stale membership or seat'; end if;
 begin perform play_game('fruit_wheel',1,'spin',null,'repair-outside','00000000-0000-4000-8000-000000000201'); raise exception 'Outside game unexpectedly allowed'; exception when raise_exception then if sqlerrm<>'ROOM_MEMBERSHIP_REQUIRED' then raise; end if; end;
 end $$;
reset role;
do $$ declare v jsonb; begin
 if exists(select 1 from room_messages where user_id='00000000-0000-4000-8000-000000000102') then raise exception 'Departed chat retained'; end if;
 if not can_moderate('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000102') then raise exception 'Moderator assignment lost'; end if;
 v:=voice_access('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000102'); if (v->>'allowed')::boolean then raise exception 'Departed voice allowed'; end if;
 end $$;
select 'premium backend authorization/room behavior passed' result;
-- Economy and cryptographic game execution use ONLY rollback fixtures.
insert into public.gifts(id,name,category,coin_price,min_vip,min_svip,active) values('00000000-0000-4000-8000-000000000301','Repair fixture','classic',1000,0,0,true);
insert into public.moments(id,author_id,body) values('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','Repair moment');
insert into public.room_members(room_id,user_id) values('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000102'),('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000103');
update public.wallets set coins=10000 where user_id='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ declare a jsonb;b jsonb; begin
 a:=send_gift('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'repair-gift');
 if a->>'diamonds'<>'450' or a->>'room_coins'<>'50' then raise exception 'Incorrect gift split: %',a; end if;
 b:=send_gift('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'repair-gift'); if b->>'status'<>'replayed' then raise exception 'Gift replay failed'; end if;
 perform send_moment_gift('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'repair-moment-gift');
 a:=play_game('fruit_wheel',1,'spin',null,'repair-game','00000000-0000-4000-8000-000000000201');
 b:=play_game('fruit_wheel',1,'spin',null,'repair-game','00000000-0000-4000-8000-000000000201');
 if a->>'bet_id' is distinct from b->>'bet_id' or b->>'duplicate'<>'true' then raise exception 'Game retry failed'; end if;
 end $$;
reset role;
do $$ begin
 if (select coins from wallets where user_id='00000000-0000-4000-8000-000000000101')<>50 then raise exception 'Owner reward mismatch'; end if;
 if (select diamonds from wallets where user_id='00000000-0000-4000-8000-000000000103')<>900 then raise exception 'Receiver diamonds mismatch'; end if;
 if (select lifetime_gift_coins from rooms where id='00000000-0000-4000-8000-000000000201')<>1000 then raise exception 'Room lifetime mismatch'; end if;
 if (select lifetime_gift_coins from moments where id='00000000-0000-4000-8000-000000000401')<>1000 then raise exception 'Moment lifetime mismatch'; end if;
 if (select wealth_coins from profiles where id='00000000-0000-4000-8000-000000000102')<>2000 then raise exception 'Wealth counter mismatch'; end if;
 end $$;
update public.gifts set min_vip=1 where id='00000000-0000-4000-8000-000000000301';
update public.profiles set vip_level=5,vip_expires_at=now()-interval '1 day' where id='00000000-0000-4000-8000-000000000102';
update public.rooms set perm_game=false where id='00000000-0000-4000-8000-000000000201';
set local role authenticated;
do $$ begin
 begin perform send_gift('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'repair-expired'); raise exception 'Expired VIP gift allowed'; exception when raise_exception then if sqlerrm<>'gift tier required' then raise; end if; end;
 begin perform send_moment_gift('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'repair-moment-expired'); raise exception 'Expired VIP moment gift allowed'; exception when raise_exception then if sqlerrm<>'gift tier required' then raise; end if; end;
 begin perform play_game('fruit_wheel',1,'spin',null,'repair-disabled','00000000-0000-4000-8000-000000000201'); raise exception 'Disabled game allowed'; exception when raise_exception then if sqlerrm<>'ROOM_GAME_DISABLED' then raise; end if; end;
 end $$;
reset role;
select 'premium backend economy/game behavior passed' result;
-- Re-entry sees only current-session chat; other members' old messages are preserved.
insert into public.room_messages(room_id,user_id,body,created_at) values('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000103','Prior session retained',clock_timestamp()-interval '1 hour');
set local role authenticated;
select leave_room('00000000-0000-4000-8000-000000000201');
do $$ declare r jsonb; begin r:=my_rooms(); if jsonb_array_length(r->'recent')<>1 then raise exception 'Recent room lost on leaving'; end if; end $$;
select join_room('00000000-0000-4000-8000-000000000201');
do $$ begin if exists(select 1 from room_messages where room_id='00000000-0000-4000-8000-000000000201') then raise exception 'Re-entry exposed previous session chat'; end if; end $$;
select send_room_chat('00000000-0000-4000-8000-000000000201','Current session visible');
do $$ begin if not exists(select 1 from room_messages where body='Current session visible') then raise exception 'Current session chat missing'; end if; end $$;
reset role;
do $$ begin if not exists(select 1 from room_messages where body='Prior session retained') then raise exception 'Other member chat removed'; end if; end $$;
select 'premium backend reentry/history behavior passed' result;

-- ONLY run against the disposable schema clone created by tools/verify_backend_contracts.py.
-- This is a targeted backend suite; it never calls a game engine or external service.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000101','owner@test.invalid'),
 ('00000000-0000-4000-8000-000000000102','sender@test.invalid'),
 ('00000000-0000-4000-8000-000000000103','receiver@test.invalid');
update public.wallets set coins=100000;
insert into public.gifts(id,name,category,coin_price) values
 ('00000000-0000-4000-8000-000000000301','Local contract fixture','test',1000);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000101';
set local role authenticated;
select public.create_room('Contract fixture','Pakistan',null) as room_id \gset
reset role;
select set_config('nimzo_test.room', :'room_id', true);
do $$ begin
 if exists(select 1 from rooms r join profiles p on p.id=r.owner_id where r.room_no<>p.nimzo_id) then raise exception 'Room number differs from permanent ID'; end if;
 if (select count(*) from mic_seats where room_id=current_setting('nimzo_test.room')::uuid)<>10 then raise exception 'Expected ten seats'; end if;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000102';
set local role authenticated;
select public.join_room(current_setting('nimzo_test.room')::uuid);
reset role;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000103';
set local role authenticated;
select public.create_room('Other contract fixture','Pakistan',null) as other_room_id \gset
select public.leave_room(:'other_room_id');
select public.join_room(current_setting('nimzo_test.room')::uuid);
reset role;
insert into public.moments(id,author_id,body) values
 ('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','Local contract fixture');
select set_config('nimzo_test.other_room', :'other_room_id', true);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ begin
 begin perform join_room(current_setting('nimzo_test.other_room')::uuid); raise exception 'FAIL: simultaneous room membership allowed';
 exception when raise_exception then if sqlerrm<>'leave your current room first' then raise; end if; end;
 if (select count(*) from room_members where user_id=auth.uid())<>1 then raise exception 'Expected one membership'; end if;
 if exists(select 1 from wallets where user_id<>auth.uid()) then raise exception 'RLS exposed another wallet'; end if;
 if has_column_privilege('authenticated','public.profiles','wealth_coins','UPDATE') or has_column_privilege('authenticated','public.wallets','coins','UPDATE') then raise exception 'Protected counters writable'; end if;
 update profiles set language='ar',country_name='Pakistan' where id=auth.uid();
 if not exists(select 1 from profiles where id=auth.uid() and language='ar') then raise exception 'Language persistence failed'; end if;
end $$;
select 'PASS room IDs, ten seats, one membership, wallet RLS and persisted settings' as result;
-- Exact server settlement and replay, then changed recipient/quantity/room rejection.
do $$ declare r uuid:=current_setting('nimzo_test.room')::uuid; a jsonb; b jsonb; begin
 a:=send_gift(r,'00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'target-room');
 if a->>'diamonds'<>'450' or a->>'room_coins'<>'50' then raise exception 'Gift settlement split mismatch'; end if;
 b:=send_gift(r,'00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'target-room');
 if b->>'status'<>'replayed' then raise exception 'Identical replay failed'; end if;
 begin perform send_gift(r,auth.uid(),'00000000-0000-4000-8000-000000000301',1,'target-room'); raise exception 'FAIL: changed room gift recipient accepted';
 exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise; end if; end;
 begin perform send_gift(r,'00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',2,'target-room'); raise exception 'FAIL: changed room gift quantity accepted';
 exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise; end if; end;
 begin perform send_gift(current_setting('nimzo_test.other_room')::uuid,'00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'target-room'); raise exception 'FAIL: changed gift room accepted';
 exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise; end if; end;
end $$;
select 'PASS room gift settlement and payload-bound replay' as result;
do $$ declare a jsonb; begin
 a:=send_moment_gift('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'target-moment');
 if a->>'diamonds'<>'450' then raise exception 'Moment settlement mismatch'; end if;
 a:=send_moment_gift('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',1,'target-moment');
 if a->>'status'<>'replayed' then raise exception 'Moment replay failed'; end if;
 begin perform send_moment_gift('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000301',2,'target-moment'); raise exception 'FAIL: changed Moment gift quantity accepted';
 exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise; end if; end;
end $$;
select 'PASS Moment gift settlement and payload-bound replay' as result;
select send_gift(current_setting('nimzo_test.room')::uuid,auth.uid(),'00000000-0000-4000-8000-000000000301',1,'target-self');
do $$ begin
 if exists(select 1 from leaderboard('charm','weekly',100) where id=auth.uid()) then raise exception 'FAIL: self-gift generated Charm rank'; end if;
 if (select score from leaderboard('charm','weekly',100) where id='00000000-0000-4000-8000-000000000103')<>900 then raise exception 'Charm differs from diamonds'; end if;
 begin perform leaderboard('wealth','daily',10); raise exception 'FAIL: daily silently returned weekly';
 exception when raise_exception then if sqlerrm<>'unsupported ranking period' then raise; end if; end;
end $$;
select 'PASS Charm matches settled diamonds and unsupported ranking periods fail closed' as result;
reset role;
insert into room_messages(room_id,user_id,body,created_at) values
 (current_setting('nimzo_test.room')::uuid,'00000000-0000-4000-8000-000000000103','Other prior session',clock_timestamp()-interval '1 hour');
set local role authenticated;
select send_room_chat(current_setting('nimzo_test.room')::uuid,'Current session');
do $$ begin
 if exists(select 1 from room_messages where body='Other prior session') then raise exception 'Prior session exposed'; end if;
 if not exists(select 1 from room_messages where body='Current session') then raise exception 'Current chat hidden'; end if;
end $$;
select leave_room(current_setting('nimzo_test.room')::uuid);
select join_room(current_setting('nimzo_test.room')::uuid);
do $$ begin if exists(select 1 from room_messages where room_id=current_setting('nimzo_test.room')::uuid) then raise exception 'Reentry exposed old messages'; end if; end $$;
reset role;
do $$ begin
 if not exists(select 1 from room_messages where body='Other prior session') then raise exception 'Other chat was removed'; end if;
 if (select coins from wallets where user_id='00000000-0000-4000-8000-000000000102')<>97000 then raise exception 'Sender debited twice'; end if;
 if (select diamonds from wallets where user_id='00000000-0000-4000-8000-000000000103')<>900 then raise exception 'Receiver settlement incorrect'; end if;
 if (select wealth_coins from profiles where id='00000000-0000-4000-8000-000000000102')<>3000 then raise exception 'Wealth total incorrect'; end if;
 if (select charm_diamonds from profiles where id='00000000-0000-4000-8000-000000000103')<>900 then raise exception 'Charm total incorrect'; end if;
end $$;
select 'PASS server chat reentry/cleanup and real progress totals' as result;
-- Expired counters are historical, never current-cycle progress.
update profiles set svip_cycle_cents=20000,svip_level=2,
 svip_cycle_start=now()-interval '91 days'
 where id='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ declare status jsonb:=vip_status(); begin
 if status->>'svip_level'<>'0' or status->>'svip_cycle_cents'<>'0'
   or status->>'svip_cycle_active'<>'false' then raise exception 'Expired cycle exposed as current progress'; end if;
end $$;
reset role;
update profiles set svip_cycle_start=now()-interval '1 day'
 where id='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ declare status jsonb:=vip_status(); begin
 if status->>'svip_cycle_cents'<>'20000' or status->>'svip_cycle_active'<>'true'
   or status->>'svip_level'<>'2' then raise exception 'Active cycle progress incorrect'; end if;
end $$;
reset role;
select 'PASS server-authoritative active and expired SVIP cycle progress' as result;
update profiles set svip_cycle_start=null,svip_cycle_cents=2500,svip_level=0
 where id='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$ declare status jsonb:=vip_status(); begin
 if status->>'svip_cycle_cents'<>'2500' or status->>'svip_cycle_active'<>'false'
   or status->>'svip_level'<>'0' then raise exception 'Pre-activation recharge progress lost'; end if;
end $$;
reset role;
select 'PASS pre-activation recharge retained below first SVIP threshold' as result;
rollback;

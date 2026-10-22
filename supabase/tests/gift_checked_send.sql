-- DISPOSABLE DATABASE ONLY. Run through tools/test_gift_checked_send.py.
-- All seeded financial data is fictional and rolls back at the end.
begin;
create function pg_temp.expect_error(p_sql text,p_message text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_message in sqlerrm)>0 then return; end if;
    raise exception 'Expected %, got %',p_message,sqlerrm;
  end;
  raise exception 'Expected error %, statement succeeded: %',p_message,p_sql;
end;
$$;
create function pg_temp.check_true(p_condition boolean,p_label text) returns void language plpgsql as $$
begin
  if p_condition is not true then raise exception 'FAIL: %',p_label; end if;
end;
$$;

insert into public.profiles(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003'),
 ('00000000-0000-0000-0000-000000000004');
insert into public.wallets(user_id,coins) select id,10000 from public.profiles;
insert into public.rooms(id,owner_id) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003');
insert into public.room_members(room_id,user_id)
 select '10000000-0000-0000-0000-000000000001',id from public.profiles;
insert into public.moments(id,author_id) values
 ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002');
insert into public.gifts(id,coin_price) values
 ('30000000-0000-0000-0000-000000000001',100),
 ('30000000-0000-0000-0000-000000000002',100);
insert into public.gift_animation_media(gift_id,approved,video_url,media_kind,sha256,byte_size,mime_type,rights_reference,verified_at,device_verified_at)
 values ('30000000-0000-0000-0000-000000000001',true,
 'https://approved.example/media/'||repeat('a',64)||'.mp4','vap',repeat('a',64),1000,'video/mp4','disposable approved fixture',now(),now());
update public.gifts set active=true where id='30000000-0000-0000-0000-000000000001';

-- No unauthenticated endpoint access, including both private implementations.
select pg_temp.check_true(not has_function_privilege('anon','public.send_gift_checked(uuid,uuid,uuid,integer,text,bigint)','EXECUTE'),'anon room denied');
select pg_temp.check_true(not has_function_privilege('anon','public.send_moment_gift_checked(uuid,uuid,uuid,integer,text,bigint)','EXECUTE'),'anon moment denied');
select pg_temp.check_true(not has_function_privilege('anon','public.send_profile_gift_checked(uuid,uuid,integer,text,bigint)','EXECUTE'),'anon profile denied');
select pg_temp.check_true(not has_function_privilege('anon','public.gift_send_receipt_checked(uuid,uuid,integer,text,bigint,text,uuid)','EXECUTE'),'anon receipt denied');
select pg_temp.check_true(not has_function_privilege('anon','nimzo_private.send_gift_checked(uuid,uuid,integer,text,bigint,text,uuid)','EXECUTE'),'anon private denied');
select pg_temp.check_true(not has_table_privilege('authenticated','public.ledger','SELECT'),'no direct ledger read grant');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'auth',100)$q$,'not authenticated');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true(public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200,'room','10000000-0000-0000-0000-000000000001') is null,'fresh receipt null');
select pg_temp.check_true((select count(*) from public.ledger)=0,'receipt never settles');

-- A changed price is rejected BEFORE the existing settlement touches balances.
select pg_temp.expect_error($q$select public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'stale',198)$q$,'gift price changed');
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'stale-profile',198)$q$,'gift price changed');
select pg_temp.expect_error($q$select public.send_moment_gift_checked('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'stale-moment',198)$q$,'gift price changed');
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=10000,'stale price no debit');
select pg_temp.check_true((select count(*) from public.ledger)=0,'stale price no ledger');

-- Invoker façade works through an authenticated role without financial access.
set local role authenticated;
select public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200);
reset role;
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=9800,'room original debit');
select pg_temp.check_true((select diamonds from public.wallets where user_id='00000000-0000-0000-0000-000000000002')=90,'room original 45 percent credit');
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000003')=10010,'room original 5 percent owner credit');
select pg_temp.check_true((select count(*) from public.gift_events)=1,'room one event');

-- Lost successful response: receipt/retry succeed despite a changed price,
-- disabled gift/media, closed room, and restricted sender. Nothing is charged.
update public.gifts set coin_price=999,active=false;
update public.gift_animation_media set approved=false;
update public.rooms set status='closed';
update public.profiles set status='restricted' where id='00000000-0000-0000-0000-000000000001';
select pg_temp.check_true(public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200,'room','10000000-0000-0000-0000-000000000001')='{"status":"replayed","total":200,"diamonds":90,"room_coins":10}'::jsonb,'receipt original economics after removal');
select pg_temp.check_true(public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200)->>'status'='replayed','retry bypasses current availability');
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=9800,'replay no second debit');
select pg_temp.check_true((select count(*) from public.gift_events)=1,'replay no event/rocket duplicate');

-- A successful key is bound to the exact original scope/context/recipient/gift/
-- quantity/confirmed total. Changing ANY field must fail, even after removal.
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001',2,'room',200,'room','10000000-0000-0000-0000-000000000001')$q$,'idempotency payload mismatch');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002',2,'room',200,'room','10000000-0000-0000-0000-000000000001')$q$,'idempotency payload mismatch');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',3,'room',200,'room','10000000-0000-0000-0000-000000000001')$q$,'idempotency payload mismatch');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',1998,'room','10000000-0000-0000-0000-000000000001')$q$,'idempotency payload mismatch');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200,'room','10000000-0000-0000-0000-000000000002')$q$,'idempotency payload mismatch');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200,'moment','10000000-0000-0000-0000-000000000001')$q$,'idempotency payload mismatch');
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200)$q$,'idempotency payload mismatch');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select pg_temp.check_true(public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',2,'room',200,'room','10000000-0000-0000-0000-000000000001') is null,'receipt private to original sender');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);

-- Restore only disposable fixture availability for independent fresh sends.
update public.gifts set coin_price=100;
update public.gift_animation_media set approved=true;
update public.gifts set active=true where id='30000000-0000-0000-0000-000000000001';
update public.rooms set status='open';
update public.profiles set status='active';
select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',3,'profile',300);
select public.send_moment_gift_checked('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',4,'moment',400);
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=9100,'profile plus moment original debit');
select pg_temp.check_true((select diamonds from public.wallets where user_id='00000000-0000-0000-0000-000000000002')=405,'profile plus moment original credits');
select pg_temp.check_true((select lifetime_gift_coins from public.moments where id='20000000-0000-0000-0000-000000000001')=400,'moment original aggregate');
update public.gifts set active=false,coin_price=900;
update public.gift_animation_media set approved=false;
select pg_temp.check_true(public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',3,'profile',300)='{"status":"replayed","total":300,"diamonds":135}'::jsonb,'profile original receipt');
select pg_temp.check_true(public.send_moment_gift_checked('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',4,'moment',400)='{"status":"replayed","total":400,"diamonds":180}'::jsonb,'moment original receipt');
select pg_temp.check_true((select count(*) from public.gift_events)=3,'three scopes each settle once');
select pg_temp.check_true((select lifetime_gift_coins from public.moments where id='20000000-0000-0000-0000-000000000001')=400,'moment retry never inflates total');
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'disabled',900)$q$,'gift unavailable');

-- A fresh approved catalog selection still uses atomic media guards. A rejected
-- media trigger occurs AFTER original wallet writes; everything must roll back.
-- Activation requires an approved media record, so revoke approval afterwards.
update public.gift_animation_media set approved=true;
update public.gifts set active=true,coin_price=100 where id='30000000-0000-0000-0000-000000000001';
update public.gift_animation_media set approved=false;
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'bad-media',100)$q$,'Gift publication unavailable');
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=9100,'media rejection rolls back debit');
select pg_temp.check_true((select diamonds from public.wallets where user_id='00000000-0000-0000-0000-000000000002')=405,'media rejection rolls back credit');
select pg_temp.check_true((select count(*) from public.ledger where idempotency_key like 'bad-media:%')=0,'media rejection rolls back ledger');
select pg_temp.check_true((select count(*) from public.gift_events)=3,'media rejection rolls back event');
update public.gift_animation_media set approved=true;

select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',9999,'insufficient',999900)$q$,'insufficient coins');
select pg_temp.expect_error($q$select public.send_moment_gift_checked('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001',1,'wrong-moment',100)$q$,'moment receiver mismatch');
update public.rooms set gift_permission='host';
select pg_temp.expect_error($q$select public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'permission',100)$q$,'gift permission required');
update public.rooms set gift_permission='all';
insert into public.blocks values('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001');
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'blocked',100)$q$,'gift unavailable');
delete from public.blocks;
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=9100,'failed fresh requests no debit');

-- Existing settled LEGACY RPC sends can also recover through the new receipt.
select public.send_profile_gift('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'legacy');
update public.gifts set active=false,coin_price=900;
select pg_temp.check_true(public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'legacy',100)->>'status'='replayed','legacy paid receipt recovery');
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=9000,'legacy recovery no second debit');
select pg_temp.check_true((select count(*) from public.gift_events)=4,'legacy recovery no second event');

-- Self gifts keep the original 45% diamond economics; owning the room
-- never adds the nominal response's 5% back into the sender's wallet.
update public.gifts set active=true,coin_price=100 where id='30000000-0000-0000-0000-000000000001';
select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,'self-profile',100);
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=8900,'self profile full debit');
select pg_temp.check_true((select diamonds from public.wallets where user_id='00000000-0000-0000-0000-000000000001')=45,'self profile original 45 percent credit');
select pg_temp.check_true(public.send_profile_gift_checked('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,'self-profile',100)->>'diamonds'='45','self profile receipt reads actual recipient ledger');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'owner-room',100);
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000003')=9910,'owner sender no extra room reward');
select pg_temp.check_true(public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'owner-room',100)->>'room_coins'='5','owner sender retains legacy nominal response');
select pg_temp.check_true((select coins from public.wallets where user_id='00000000-0000-0000-0000-000000000003')=9910,'owner retry no second debit or reward');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);

-- Invalid/incomplete receipts never invent a credit or permit fallback sending.
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'invalid',100,'profile','10000000-0000-0000-0000-000000000001')$q$,'invalid checked gift request');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'invalid',100,'room',null)$q$,'invalid checked gift request');
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'invalid',100,null,null)$q$,'invalid checked gift request');
select pg_temp.expect_error($q$select public.send_profile_gift_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'null-total',null)$q$,'invalid checked gift request');
delete from public.ledger where idempotency_key='legacy:receiver';
select pg_temp.expect_error($q$select public.gift_send_receipt_checked('00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1,'legacy',100,'profile',null)$q$,'gift receipt incomplete');
select 'PASS: authenticated price confirmation; original payouts; three-scope replay; binding; no duplicate events; permissions; media rollback; receipt privacy';
rollback;

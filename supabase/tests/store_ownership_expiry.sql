-- DISPOSABLE DATABASE ONLY; all financial fixtures roll back.
begin;
create function pg_temp.check_true(p_value boolean,p_label text) returns void
language plpgsql as $$ begin
 if p_value is not true then raise exception 'FAIL: %',p_label; end if;
end $$;
create function pg_temp.expect_error(p_sql text,p_message text) returns void
language plpgsql as $$ begin
 begin execute p_sql;
 exception when others then
   if position(p_message in sqlerrm)>0 then return; end if;
   raise exception 'Expected %, got %',p_message,sqlerrm;
 end;
 raise exception 'Expected error %, statement succeeded',p_message;
end $$;
select pg_temp.check_true((select expires_at is null from nimzo_cosmetic_ownership
 where item_id='nimzo-original-avatar-frame-golden-stars'),'existing ownership remains lifetime');
select pg_temp.check_true((select coins=1000 from wallets),'migration never debits wallet');
select pg_temp.check_true(not has_function_privilege('anon','public.nimzo_store_purchase(text,bigint,text)','execute'),'anonymous purchase denied');
select pg_temp.check_true(not has_function_privilege('anon','public.store_purchase_receipt(text,bigint,text)','execute'),'anonymous receipt denied');
select pg_temp.check_true(not has_table_privilege('authenticated','nimzo_internal.store_no_charge_receipts','SELECT'),'private nocharge receipts not exposed');
select pg_temp.check_true(not has_function_privilege('anon','public.nimzo_store_visual_equipment(uuid[])','execute'),'anonymous equipment denied');
select pg_temp.check_true(not has_table_privilege('authenticated','public.nimzo_cosmetic_ownership','UPDATE'),'no direct entitlement writes');
select pg_temp.check_true(not has_table_privilege('authenticated','public.ledger','SELECT'),'ledger remains private');
select pg_temp.expect_error($q$insert into nimzo_cosmetic_catalog(id,category,name,variant,duration_days) values('invalid-zero','Rides','Invalid',0,0)$q$,'nimzo_cosmetic_duration_days_check');
select pg_temp.expect_error($q$insert into nimzo_cosmetic_catalog(id,category,name,variant,duration_days) values('invalid-huge','Rides','Invalid',0,3651)$q$,'nimzo_cosmetic_duration_days_check');
insert into nimzo_cosmetic_catalog(id,category,name,variant,coin_price,duration_days) values
 ('fixture-paid-timed','Avatar Frame','Timed frame',0,100,7),
 ('fixture-paid-lifetime','Rides','Lifetime ride',0,100,null),
 ('fixture-free-timed','Live Frame','Free timed frame',0,0,3),
 ('fixture-corrupt-media','Chat Bubble','Corrupt media',0,100,7),
 ('fixture-expensive','Royal Badge','Expensive item',0,900,1);
insert into nimzo_cosmetic_media(item_id,asset_url,media_kind,approved,
 sha256,byte_size,mime_type,rights_reference,verified_at,device_verified_at)
select id,'https://fixture.example/'||repeat('a',64)||'.png','image',true,
 repeat('a',64),8,'image/png','Fictional SQL fixture; no runtime claim',now(),now()
from nimzo_cosmetic_catalog where id in('fixture-paid-timed','fixture-paid-lifetime','fixture-expensive');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-paid-timed',100,repeat('1',32))$q$,'Sign in required');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select pg_temp.check_true(store_purchase_receipt('fixture-paid-timed',100,repeat('1',32)) is null,'fresh receipt read never settles');
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-timed',100,repeat('1',32))->>'status')='purchased','authenticated timed purchase');
select nimzo_store_equip_free('fixture-paid-timed');
reset role;
create temporary table original_receipt as select expires_at from nimzo_cosmetic_ownership where item_id='fixture-paid-timed';
select pg_temp.check_true((select expires_at between now()+interval '7 days' and now()+interval '7 days 10 seconds' from nimzo_cosmetic_ownership where item_id='fixture-paid-timed'),'duration comes from server');
select pg_temp.check_true((select coins=900 from wallets),'one debit');
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-timed',100,repeat('2',32))->>'status')='already_owned','early renewal refused without charge');
select pg_temp.check_true((select expires_at=(select expires_at from original_receipt) from nimzo_cosmetic_ownership where item_id='fixture-paid-timed'),'early renewal does not extend');
select pg_temp.check_true((select count(*)=1 from ledger),'early renewal no accounting charge');
select pg_temp.check_true((select count(*)=1 from nimzo_internal.store_no_charge_receipts),'early renewal has private durable zerocharge receipt');
select pg_temp.check_true((select count(*)=1 from nimzo_store_visual_equipment(array['00000000-0000-0000-0000-000000000001'::uuid])),'active equipment visible');
update nimzo_cosmetic_ownership set expires_at=now()-interval '1 second' where item_id='fixture-paid-timed';
select pg_temp.expect_error($q$select nimzo_store_equip_free('fixture-paid-timed')$q$,'Item not owned or expired');
select pg_temp.check_true((select count(*)=0 from nimzo_store_visual_equipment(array['00000000-0000-0000-0000-000000000001'::uuid])),'expired equipment not rendered');
set local role authenticated;
select pg_temp.check_true((select count(*)=0 from nimzo_cosmetic_equipped),'RLS hides expired equipment from old clients');
select pg_temp.check_true((select count(*)=2 from nimzo_cosmetic_ownership),'own expired ownership remains readable');
select pg_temp.check_true((select expires_at is not null from nimzo_cosmetic_ownership where item_id='fixture-paid-timed'),'own expiry column readable');
reset role;
update nimzo_cosmetic_catalog set duration_days=14 where id='fixture-paid-timed';
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-timed',100,repeat('3',32))->>'status')='purchased','expired item renews');
select pg_temp.check_true((select expires_at between now()+interval '14 days' and now()+interval '14 days 10 seconds' from nimzo_cosmetic_ownership where item_id='fixture-paid-timed'),'renewal uses current server duration');
select pg_temp.check_true((select coins=800 from wallets),'renewal charged exactly once');
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-timed',100,repeat('3',32))->>'status')='replayed','renewal retry uses same receipt');
update nimzo_cosmetic_ownership set expires_at=now()-interval '1 second' where item_id='fixture-paid-timed';
update nimzo_cosmetic_catalog set active=false,coin_price=150 where id='fixture-paid-timed';
update nimzo_cosmetic_media set approved=false where item_id='fixture-paid-timed';
update profiles set status='restricted';
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-timed',100,repeat('1',32))->>'expires_at')::timestamptz=(select expires_at from original_receipt),'original receipt recovers after expiry/deactivation/account restriction');
select pg_temp.check_true((select expires_at<now() from nimzo_cosmetic_ownership where item_id='fixture-paid-timed'),'old retry does not renew');
select pg_temp.check_true((select coins=800 from wallets),'recovered receipt never debits');
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-timed',100,repeat('2',32))->>'status')='already_owned','lost zerocharge response cannot become renewal after expiry');
set local role authenticated;
select pg_temp.check_true((store_purchase_receipt('fixture-paid-timed',100,repeat('1',32))->>'total')::bigint=100,'own debit receipt read after restriction and deactivation');
select pg_temp.check_true((store_purchase_receipt('fixture-paid-timed',100,repeat('2',32))->>'total')::bigint=0,'own zerocharge receipt read after expiry');
reset role;
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-paid-timed',150,repeat('1',32))$q$,'Idempotency payload mismatch');
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-paid-timed',150,repeat('4',32))$q$,'Account unavailable');
update profiles set status='active';
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-paid-timed',150,repeat('4',32))$q$,'Paid item is not available');
update nimzo_cosmetic_catalog set active=true where id='fixture-paid-timed';
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-paid-timed',100,repeat('4',32))$q$,'Store price changed');
select pg_temp.expect_error($q$select nimzo_store_claim_free('fixture-paid-timed')$q$,'Free item not available');
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-expensive',900,repeat('7',32))$q$,'Insufficient coins');
select pg_temp.check_true(not exists(select 1 from nimzo_cosmetic_ownership where item_id='fixture-expensive'),'insufficient coins never grants ownership');
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-corrupt-media',100,repeat('5',32))$q$,'Item media not ready');
select nimzo_store_claim_free('fixture-free-timed');
create temporary table original_free as select acquired_at,expires_at from nimzo_cosmetic_ownership where item_id='fixture-free-timed';
select pg_temp.check_true((select expires_at between now()+interval '3 days' and now()+interval '3 days 10 seconds' from original_free),'free duration server-controlled');
select nimzo_store_claim_free('fixture-free-timed');
select pg_temp.check_true((select expires_at=(select expires_at from original_free) from nimzo_cosmetic_ownership where item_id='fixture-free-timed'),'free repeated claim does not extend');
update nimzo_cosmetic_ownership set expires_at=now()-interval '1 day' where item_id='fixture-free-timed';
select nimzo_store_claim_free('fixture-free-timed');
select pg_temp.check_true((select expires_at>now() from nimzo_cosmetic_ownership where item_id='fixture-free-timed'),'expired free item can be reclaimed');
select nimzo_store_claim_free('nimzo-original-avatar-frame-golden-stars');
select pg_temp.check_true((select expires_at is null from nimzo_cosmetic_ownership where item_id='nimzo-original-avatar-frame-golden-stars'),'free repeat preserves lifetime');
select nimzo_store_purchase('fixture-paid-lifetime',100,repeat('6',32));
select pg_temp.check_true((select expires_at is null from nimzo_cosmetic_ownership where item_id='fixture-paid-lifetime'),'null duration new ownership lifetime');
update nimzo_cosmetic_catalog set duration_days=1 where id='fixture-paid-lifetime';
select pg_temp.check_true((nimzo_store_purchase('fixture-paid-lifetime',100,repeat('8',32))->>'status')='already_owned','lifetime ownership cannot be charged renewal');
select pg_temp.check_true((select expires_at is null from nimzo_cosmetic_ownership where item_id='fixture-paid-lifetime'),'catalog duration update never changes existing lifetime ownership');
select pg_temp.check_true((select coins=700 from wallets),'only three genuine purchases debited');
select pg_temp.check_true((select count(*)=3 from ledger),'only genuine purchases have receipts');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000099',true);
select pg_temp.check_true(store_purchase_receipt('fixture-paid-timed',100,repeat('1',32)) is null,'receipt cannot read another account');
select pg_temp.expect_error($q$select nimzo_store_purchase('fixture-paid-timed',100,repeat('1',32))$q$,'Account unavailable');
rollback;

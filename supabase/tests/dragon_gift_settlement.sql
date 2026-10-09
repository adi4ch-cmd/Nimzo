-- Disposable schema clone ONLY. No production accounts, balances or media grants.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000101','owner@test.invalid'),
 ('00000000-0000-4000-8000-000000000102','sender@test.invalid'),
 ('00000000-0000-4000-8000-000000000103','receiver@test.invalid'),
 ('00000000-0000-4000-8000-000000000104','outsider@test.invalid');
update public.wallets set coins=20000000 where user_id='00000000-0000-4000-8000-000000000102';
insert into public.gifts(id,name,category,coin_price) values
 ('e1e65664-37f8-4cfd-9640-3bb035723b98','Dragon','test',1000000),
 ('c3f41e6e-68d5-4e56-9253-33421ec18fc3','Golden Dragon','test',5000000);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000101';
set local role authenticated;
select public.create_room('Gift fixture','Pakistan',null) as room_id \gset
reset role;
select set_config('nimzo_test.room', :'room_id', true);
-- Room gifts must produce verified events even without optional country data.
update rooms set country='' where id=:'room_id';
update profiles set country_code=null where id='00000000-0000-4000-8000-000000000101';
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000103';
set local role authenticated;
select public.join_room(:'room_id');
reset role;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000102';
set local role authenticated;
select public.join_room(:'room_id');
do $$ declare r uuid:=current_setting('nimzo_test.room')::uuid; a jsonb; begin
 a:=send_gift(r,'00000000-0000-4000-8000-000000000103','e1e65664-37f8-4cfd-9640-3bb035723b98',3,'dragon-qty');
 if a->>'total'<>'3000000' or a->>'diamonds'<>'1350000' or a->>'room_coins'<>'150000' then raise exception 'Dragon split incorrect'; end if;
 a:=send_gift(r,'00000000-0000-4000-8000-000000000103','e1e65664-37f8-4cfd-9640-3bb035723b98',3,'dragon-qty');
 if a->>'status'<>'replayed' then raise exception 'Dragon retry failed'; end if;
 begin perform send_gift(r,'00000000-0000-4000-8000-000000000103','e1e65664-37f8-4cfd-9640-3bb035723b98',4,'dragon-qty'); raise exception 'FAIL changed payload accepted';
 exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise; end if; end;
 a:=send_gift(r,'00000000-0000-4000-8000-000000000103','c3f41e6e-68d5-4e56-9253-33421ec18fc3',2,'golden-qty');
 if a->>'total'<>'10000000' or a->>'diamonds'<>'4500000' or a->>'room_coins'<>'500000' then raise exception 'Golden split incorrect'; end if;
 a:=send_gift(r,auth.uid(),'e1e65664-37f8-4cfd-9640-3bb035723b98',1,'dragon-self');
 if a->>'total'<>'1000000' or a->>'diamonds'<>'0' then raise exception 'Self-gift economy changed'; end if;
 begin perform send_gift(r,'00000000-0000-4000-8000-000000000104','e1e65664-37f8-4cfd-9640-3bb035723b98',1,'outside'); raise exception 'FAIL nonmember accepted';
 exception when raise_exception then if sqlerrm<>'room member required' then raise; end if; end;
 begin perform send_gift(r,auth.uid(),'c3f41e6e-68d5-4e56-9253-33421ec18fc3',2,'insufficient'); raise exception 'FAIL insufficient accepted';
 exception when raise_exception then if sqlerrm<>'insufficient coins' then raise; end if; end;
 begin perform send_gift(r,auth.uid(),'e1e65664-37f8-4cfd-9640-3bb035723b98',0,'zero'); raise exception 'FAIL zero accepted';
 exception when raise_exception then if sqlerrm<>'invalid gift request' then raise; end if; end;
end $$;
reset role;
do $$ begin
 if (select coins from wallets where user_id='00000000-0000-4000-8000-000000000102')<>6000000 then raise exception 'Sender debit/retry incorrect'; end if;
 if (select diamonds from wallets where user_id='00000000-0000-4000-8000-000000000103')<>5850000 then raise exception 'Recipient credit incorrect'; end if;
 if (select diamonds from wallets where user_id='00000000-0000-4000-8000-000000000102')<>0 then raise exception 'Self gift minted diamonds'; end if;
 if (select coins from wallets where user_id='00000000-0000-4000-8000-000000000101')<>700000 then raise exception 'Owner credit incorrect'; end if;
 if (select count(*) from gift_events)<>3 then raise exception 'Duplicate or failed gift recorded'; end if;
 if (select count(*) from gift_animation_events)<>3 then raise exception 'Missing verified room events without country'; end if;
 if not exists(select 1 from gift_animation_events where gift_id='c3f41e6e-68d5-4e56-9253-33421ec18fc3' and quantity=2 and unit_price=5000000 and scope='room') then raise exception 'Golden media event mapping incorrect'; end if;
 if exists(select 1 from gift_animation_events where scope<>'room') then raise exception 'Room scope incorrect'; end if;
 if has_table_privilege('authenticated','gift_animation_events','insert') then raise exception 'Client can forge gift effects'; end if;
end $$;
-- Trigger prices must reflect settled totals even if catalog prices change.
update public.gifts set coin_price=35000000 where id='e1e65664-37f8-4cfd-9640-3bb035723b98';
insert into public.gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
values(current_setting('nimzo_test.room')::uuid,
 '00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000103',
 'e1e65664-37f8-4cfd-9640-3bb035723b98',2,2000000);
do $$ begin
 if not exists(select 1 from gift_animation_events where gift_id='e1e65664-37f8-4cfd-9640-3bb035723b98' and quantity=2 and unit_price=1000000 and scope='room') then raise exception 'Event used mutable catalog price'; end if;
end $$;
-- A country-wide effect cannot escape into other countries without a scope.
insert into public.gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
values(current_setting('nimzo_test.room')::uuid,
 '00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000103',
 'e1e65664-37f8-4cfd-9640-3bb035723b98',1,35000000);
do $$ begin
 if (select count(*) from gift_animation_events)<>4 then raise exception 'Country effect emitted without country'; end if;
end $$;
update profiles set country_code='PK' where id='00000000-0000-4000-8000-000000000101';
insert into public.gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
values(current_setting('nimzo_test.room')::uuid,
 '00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000103',
 'e1e65664-37f8-4cfd-9640-3bb035723b98',1,35000000);
do $$ begin
 if not exists(select 1 from gift_animation_events where unit_price=35000000 and scope='country' and country_code='PK') then raise exception 'Country effect not scoped'; end if;
end $$;
select 'PASS Dragon and Golden Dragon quantities, credits, self-gifts, retries, rejection and verified events' as result;
rollback;

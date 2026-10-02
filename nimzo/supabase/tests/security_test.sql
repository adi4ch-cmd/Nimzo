-- Run in the Supabase SQL editor or `psql`. Everything is rolled back at the end.
begin;
create or replace function pg_temp.expect_fail(p_sql text, p_label text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception 'SECURITY FAIL: % succeeded', p_label using errcode = 'SF001';
  exception
    when sqlstate 'SF001' then raise;
    when others then raise notice 'ok (blocked): %', p_label;
  end;
end $$;

insert into auth.users(id,email) values
  ('00000000-0000-0000-0000-0000000000a1','sender@test.local'),
  ('00000000-0000-0000-0000-0000000000a2','receiver@test.local'),
  ('00000000-0000-0000-0000-0000000000a3','owner@test.local');
update wallets set coins=100000 where user_id='00000000-0000-0000-0000-0000000000a1';
insert into rooms(id,owner_id,name) values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a3','T');
insert into gifts(id,name,category,coin_price) values ('00000000-0000-0000-0000-0000000000c1','Test','popular',100000);

-- Economy: 100000 sent -> 45000 diamonds + 5000 owner coins
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a1',true);
select send_gift('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1',1,'k1');
select send_gift('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1',1,'k1'); -- replay: no double charge
reset role;
do $$ begin
  assert (select diamonds from wallets where user_id='00000000-0000-0000-0000-0000000000a2')=45000, 'receiver diamonds';
  assert (select coins from wallets where user_id='00000000-0000-0000-0000-0000000000a3')=5000, 'owner coins';
  assert (select coins from wallets where user_id='00000000-0000-0000-0000-0000000000a1')=0, 'sender coins';
  raise notice 'ok: economy 100000 -> 45000 + 5000, replay safe';
end $$;

-- Client tampering must all fail
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a1',true);
select pg_temp.expect_fail($q$update wallets set coins=999999999$q$, 'edit own coins');
select pg_temp.expect_fail($q$update wallets set diamonds=999999999$q$, 'edit own diamonds');
select pg_temp.expect_fail($q$update profiles set vip_level=10$q$, 'set own VIP');
select pg_temp.expect_fail($q$update profiles set svip_level=8$q$, 'set own SVIP');
select pg_temp.expect_fail($q$update profiles set level=99$q$, 'set own level');
select pg_temp.expect_fail($q$insert into admins values ('00000000-0000-0000-0000-0000000000a1')$q$, 'make self admin');
select pg_temp.expect_fail($q$update rooms set owner_id='00000000-0000-0000-0000-0000000000a1'$q$, 'take room ownership');
select pg_temp.expect_fail($q$insert into room_members values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a1','moderator')$q$, 'self moderator');
select pg_temp.expect_fail($q$insert into ledger(user_id,kind,coin_delta,idempotency_key) values ('00000000-0000-0000-0000-0000000000a1','x',100,'z')$q$, 'forge ledger');
select pg_temp.expect_fail($q$select apply_recharge('00000000-0000-0000-0000-0000000000a1','g','t','p')$q$, 'call apply_recharge');
select pg_temp.expect_fail($q$select activate_vip('00000000-0000-0000-0000-0000000000a1',10)$q$, 'call activate_vip');
select pg_temp.expect_fail($q$select admin_set_status('00000000-0000-0000-0000-0000000000a2','banned')$q$, 'admin action as user');
select pg_temp.expect_fail($q$select reseller_recharge('00000000-0000-0000-0000-0000000000a1',1000,'r')$q$, 'reseller without role');
select pg_temp.expect_fail($q$select update_room_settings('00000000-0000-0000-0000-0000000000b1','{"theme":"luxury"}')$q$, 'non-owner edits room');
reset role;
rollback;

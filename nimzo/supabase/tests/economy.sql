-- Runnable economy test. Paste into the Supabase SQL editor (runs as postgres). Rolls back at the end.
begin;
do $$
declare s uuid := gen_random_uuid(); r uuid := gen_random_uuid(); o uuid := gen_random_uuid();
        room uuid; g uuid; res jsonb; sc bigint; rd bigint; oc bigint;
begin
  insert into auth.users(id,email) values (s,'s@test.dev'),(r,'r@test.dev'),(o,'o@test.dev');
  insert into rooms(owner_id,name) values (o,'Test') returning id into room;
  insert into room_members(room_id,user_id) values (room,r),(room,s);
  insert into gifts(name,category,coin_price) values ('T','popular',100000) returning id into g;
  update wallets set coins=100000 where user_id=s;

  perform set_config('request.jwt.claim.sub', s::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', s)::text, true);
  res := send_gift(room, r, g, 1, 'k1');
  select coins into sc from wallets where user_id=s;
  select diamonds into rd from wallets where user_id=r;
  select coins into oc from wallets where user_id=o;
  assert sc = 0,      'sender should have 0 coins';
  assert rd = 45000,  'receiver should get 45000 diamonds';
  assert oc = 5000,   'room owner should get 5000 coins';

  -- replay with the same key must not charge again
  update wallets set coins=100000 where user_id=s;
  perform send_gift(room, r, g, 1, 'k1');
  select coins into sc from wallets where user_id=s;
  assert sc = 100000, 'idempotent replay must not charge';

  -- insufficient balance must fail
  update wallets set coins=10 where user_id=s;
  begin perform send_gift(room, r, g, 1, 'k2'); assert false, 'should have failed';
  exception when others then if sqlerrm not like '%insufficient%' then raise; end if; end;
  raise notice 'economy tests passed';
end $$;
rollback;

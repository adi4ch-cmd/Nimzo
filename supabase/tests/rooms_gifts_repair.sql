-- Run with the project SQL executor. Everything, including real RPC settlement,
-- is rolled back. Existing account, room and wallet data are not retained here.
begin;
create temporary table repair_results(test text, passed boolean) on commit drop;
do $$
declare
  r record;
  gift uuid;
  price bigint;
  key text;
  before_coins bigint;
  before_diamonds bigint;
  before_total bigint;
  after_total bigint;
  result jsonb;
begin
  select id,coin_price into strict gift,price
    from public.gifts where active and lower(name)='sports car';
  for r in select id,owner_id from public.rooms where status='open' loop
    perform set_config('request.jwt.claims',
      jsonb_build_object('sub',r.owner_id,'role','authenticated')::text,true);
    set local role authenticated;
    perform public.join_room(r.id,null);
    select coins,diamonds into before_coins,before_diamonds
      from public.wallets where user_id=auth.uid();
    before_total := (public.room_diamond_status(r.id)->>'total_coins')::bigint;
    key := 'repair-audit-'||gen_random_uuid()::text;
    result := public.send_gift(r.id,r.owner_id,gift,1,key);
    if result->>'status' <> 'ok' then raise exception 'Settlement failed'; end if;
    if not exists(select 1 from public.wallets where user_id=auth.uid()
      and coins=before_coins-price and diamonds=before_diamonds+price*45/100)
      then raise exception 'Self-gift wallet split mismatch'; end if;
    after_total := (public.room_diamond_status(r.id)->>'total_coins')::bigint;
    if after_total <> before_total+price then raise exception 'Rocket total mismatch'; end if;
    if not public.my_daily_room_gift_status() then raise exception 'Gift task not completed'; end if;
    if not exists(select 1 from public.gift_animation_events
      where room_id=r.id and sender_id=auth.uid() and gift_id=gift
        and created_at >= statement_timestamp())
      then raise exception 'Verified animation event is not readable'; end if;
    result := public.send_gift(r.id,r.owner_id,gift,1,key);
    if result->>'status' <> 'replayed' then raise exception 'Retry not idempotent'; end if;
    if (public.room_diamond_status(r.id)->>'total_coins')::bigint <> after_total
      then raise exception 'Retry counted twice'; end if;
    perform public.leave_room(r.id);
    if not public.my_daily_room_gift_status() then raise exception 'Leaving room lost task'; end if;
    reset role;
    insert into repair_results values('room settlement, wallet split, readable event, Rocket delta, retry and task after exit',true);
  end loop;
  if not exists(select 1 from repair_results) then raise exception 'No open rooms tested'; end if;
  if has_function_privilege('anon','public.my_daily_room_gift_status()','execute')
    then raise exception 'Anonymous task status access'; end if;
  if has_table_privilege('authenticated','public.gift_events','select')
    then raise exception 'Payment receipts are exposed'; end if;
  insert into repair_results values('anonymous denied; financial receipts remain private',true);
end;
$$;
select * from repair_results;
rollback;

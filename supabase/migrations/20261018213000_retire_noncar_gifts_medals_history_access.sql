-- NIMZO feature retirement. Authorized: remove all non-car gift offerings and
-- every medal entitlement. Keep financial ledgers and historic paid receipts
-- for reconciliation; wallet balances, exchange and user accounts are untouched.
-- Only Sports Car continues to be offered as a gift.
do $$
declare
  v_car uuid;
  v_car_count integer;
begin
  select count(*), (array_agg(id))[1] into v_car_count, v_car
  from public.gifts where lower(trim(name))='sports car';
  if v_car_count <> 1 then
    raise exception 'Cleanup stopped: expected one Sports Car gift, got %',v_car_count;
  end if;

  -- Idempotent catalog retirement. Existing gift_event FK links remain valid.
  update public.gifts
    set active=(id=v_car)
  where active is distinct from (id=v_car);

  -- Remove visual animation history that would replay retired gifts.
  -- Real coin ledger and gift payment receipts are not touched.
  delete from public.gift_animation_events
  where gift_id <> v_car;

  -- Disable all medal listings before erasing equipped/owned medal state.
  update public.nimzo_store_catalog
  set active=false
  where collectible_id in
      (select id from public.profile_collectibles where kind='medal');

  delete from public.profile_owned_collectibles
  where collectible_id in
      (select id from public.profile_collectibles where kind='medal');

  delete from public.nimzo_store_catalog
  where collectible_id in
      (select id from public.profile_collectibles where kind='medal');

  delete from public.profile_collectibles where kind='medal';
end;
$$;

-- Older APKs cannot access retired medal purchase/equip RPCs or
-- query the legacy received-gift history RPC.
revoke execute on function public.nimzo_store_buy(uuid,text)
  from public, anon, authenticated;
revoke execute on function public.nimzo_store_equip(uuid)
  from public, anon, authenticated;
revoke execute on function public.profile_gifts(uuid)
  from public, anon, authenticated;

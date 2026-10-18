-- Final removal of obsolete user-facing gift history and medal Store RPCs.
-- Only Sports Car can still be sent via the existing secure send_gift RPC.
-- Fail closed if any Store catalog inventory reappeared during cleanup.
do $$
begin
  if exists(select 1 from public.nimzo_store_catalog limit 1) then
    raise exception 'Refusing to remove Store catalog: rows still present';
  end if;
end;
$$;
drop function if exists public.profile_gifts(uuid);
drop function if exists public.nimzo_store_buy(uuid,text);
drop function if exists public.nimzo_store_equip(uuid);
drop table if exists public.nimzo_store_catalog restrict;
-- Do NOT delete payment receipts or the coin ledger.

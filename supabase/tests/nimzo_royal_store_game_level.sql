-- Read-only catalog/contract test; run after migration in a test database.
begin;
do $$
begin
  if (select count(*) from public.nimzo_store_catalog where active) <> 6 then
    raise exception 'Expected six approved NIMZO Royal store items';
  end if;
  if (select count(*) from public.profile_collectibles where image_path like 'assets/hilo/store/%') <> 6 then
    raise exception 'Store catalog assets not linked to collectibles';
  end if;
  if not exists (select 1 from pg_proc where oid='public.nimzo_store_buy(uuid,text)'::regprocedure and prosecdef) then
    raise exception 'Missing server-authoritative buy RPC';
  end if;
  if not exists (select 1 from pg_proc where oid='public.nimzo_store_equip(uuid)'::regprocedure and prosecdef) then
    raise exception 'Missing server-authoritative equip RPC';
  end if;
  if (select public.nimzo_game_level()->>'level')::integer not between 0 and 15 then
    raise exception 'Game level calculation out of range';
  end if;
end $$;
rollback;

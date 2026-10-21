-- User selected one complete, matching six-level Haza set instead of mixed APKs.
-- Retain every previously settled event and all wallet/gift records.
begin;
create or replace function nimzo_private.room_rocket_targets_v2() returns bigint[]
language sql immutable set search_path='' as $$
 select array[5000000,10000000,20000000,30000000,50000000,100000000]::bigint[]
$$;
do $six$
declare definition text; patched text;
begin
 definition:=pg_get_functiondef('nimzo_private.room_diamond_settled()'::regprocedure);
 if position('for v_stage in 0..10 loop' in definition)=0 then
  raise exception 'Unrecognized Rocket trigger; review required';
 end if;
 patched:=replace(definition,'for v_stage in 0..10 loop','for v_stage in 0..5 loop');
 execute patched;
end $six$;
-- Preserve the newer endpoint for clients that already discovered it.
create or replace function public.room_rocket_status_v2(p_room uuid) returns jsonb
language sql security invoker set search_path='' as $$
 select public.room_diamond_status(p_room)
$$;
revoke all on function public.room_rocket_status_v2(uuid) from public,anon;
grant execute on function public.room_rocket_status_v2(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

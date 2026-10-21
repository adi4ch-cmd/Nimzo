-- Five complete distinct Hafla Rocket visuals extend the original six milestones.
-- Display effects only: no wallet debit, payout, or reward rule changes.
-- Keep public.room_diamond_status unchanged so existing APKs retain six-stage status.
begin;
create function nimzo_private.room_rocket_targets_v2() returns bigint[]
language sql immutable set search_path='' as $$
 select array[5000000,10000000,20000000,30000000,50000000,100000000,150000000,200000000,300000000,500000000,1000000000]::bigint[]
$$;
revoke all on function nimzo_private.room_rocket_targets_v2() from public,anon,authenticated;
do $extend$
declare definition text; patched text; item record;
begin
 -- Only widen the two existing milestone checks. Keep PK, uniqueness, FKs/RLS.
 for item in select conname from pg_constraint where conrelid='public.room_diamond_blast_events'::regclass
  and contype='c' and pg_get_constraintdef(oid) ~ '(stage|target_coins)' loop
  execute format('alter table public.room_diamond_blast_events drop constraint %I',item.conname);
 end loop;
 alter table public.room_diamond_blast_events add constraint rocket_stage_v2_check check(stage between 0 and 10);
 alter table public.room_diamond_blast_events add constraint rocket_target_v2_check check(target_coins=(array[5000000,10000000,20000000,30000000,50000000,100000000,150000000,200000000,300000000,500000000,1000000000]::bigint[])[stage+1]);
 definition:=pg_get_functiondef('nimzo_private.room_diamond_settled()'::regprocedure);
 patched:=regexp_replace(definition,'array\[\s*5000000\s*,\s*10000000\s*,\s*20000000\s*,\s*30000000\s*,\s*50000000\s*,\s*100000000\s*\]','nimzo_private.room_rocket_targets_v2()','gi');
 patched:=regexp_replace(patched,'0\.\.5','0..10','g');
 if patched=definition then raise exception 'Unrecognized Rocket settlement trigger; review required'; end if;
 execute patched;
 definition:=pg_get_functiondef('public.room_diamond_status(uuid)'::regprocedure);
 patched:=replace(definition,'public.room_diamond_status','public.room_rocket_status_v2');
 patched:=regexp_replace(patched,'array\[\s*5000000\s*,\s*10000000\s*,\s*20000000\s*,\s*30000000\s*,\s*50000000\s*,\s*100000000\s*\]','nimzo_private.room_rocket_targets_v2()','gi');
 patched:=regexp_replace(patched,'1\.\.6','1..11','g');
 patched:=regexp_replace(patched,'least\(v_completed,\s*5\)','least(v_completed,10)','gi');
 if patched=definition or patched not like '%public.room_rocket_status_v2%' then raise exception 'Unrecognized Rocket status; review required'; end if;
 execute patched;
end $extend$;
revoke all on function public.room_rocket_status_v2(uuid) from public,anon;
grant execute on function public.room_rocket_status_v2(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

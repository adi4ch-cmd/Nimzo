begin;
do $$ begin
 if to_regprocedure('public.room_diamond_status(uuid)') is null then raise exception 'FAIL missing Diamond Blast status RPC'; end if;
end $$;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000801','diamond1@test.invalid'),('00000000-0000-4000-8000-000000000802','diamond2@test.invalid');
insert into rooms(id,owner_id,name,status) values('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000801','Diamond','open'),('00000000-0000-4000-8000-000000000802','00000000-0000-4000-8000-000000000802','Other','open'),('00000000-0000-4000-8000-000000000803','00000000-0000-4000-8000-000000000801','Concurrent','closed');
insert into room_members(room_id,user_id) values('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000801');
do $$ begin
 if nimzo_private.room_diamond_cycle_start('2026-10-08 19:59:59+00')<>'2026-10-07 20:00+00' or nimzo_private.room_diamond_cycle_start('2026-10-08 20:00+00')<>'2026-10-08 20:00+00' then raise exception 'reset boundary'; end if;
end $$;
-- Multi-row first settlement cannot be mistaken for an existing baseline.
insert into gift_events(room_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000802',1,3000000),('00000000-0000-4000-8000-000000000802',1,3000000);
do $$ begin if (select total_coins from nimzo_private.room_diamond_cycles where room_id='00000000-0000-4000-8000-000000000802')<>6000000 then raise exception 'multi-row baseline double counted'; end if; end $$;
delete from nimzo_private.room_diamond_cycles where room_id='00000000-0000-4000-8000-000000000802';
delete from room_diamond_blast_events where room_id='00000000-0000-4000-8000-000000000802';
delete from gift_events where room_id='00000000-0000-4000-8000-000000000802';
-- Existing gifts count once, but must never replay old animations.
alter table gift_events disable trigger room_diamond_settled;
insert into gift_events(room_id,quantity,total_coins,created_at) values('00000000-0000-4000-8000-000000000801',1,6000000,statement_timestamp()),('00000000-0000-4000-8000-000000000801',1,99000000,statement_timestamp()-interval '2 days');
alter table gift_events enable trigger room_diamond_settled;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000801';
do $$ declare s jsonb; begin
 s:=room_diamond_status('00000000-0000-4000-8000-000000000801');
 if (s->>'total_coins')::bigint<>6000000 or (s->>'completed_stages')::int<>1 or (s->>'active_stage')::int<>1 or (s->>'progress')::numeric<>0.2 or jsonb_array_length(s->'thresholds')<>6 or (s->>'reset_at')::timestamptz-(s->>'cycle_start')::timestamptz<>interval '1 day' then raise exception 'baseline status %',s; end if;
 if (select count(*) from room_diamond_blast_events)<>0 then raise exception 'historical animations'; end if;
 begin perform room_diamond_status('00000000-0000-4000-8000-000000000802'); raise exception 'FAIL cross room RPC'; exception when insufficient_privilege then null; end;
 begin insert into gift_events(room_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000801',1,5000000); raise exception 'FAIL forged gift'; exception when insufficient_privilege then null; end;
 begin insert into room_diamond_blast_events(room_id,cycle_start,stage,target_coins,gift_event_id) values('00000000-0000-4000-8000-000000000801',now(),0,5000000,gen_random_uuid()); raise exception 'FAIL forged blast'; exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into gift_events(id,room_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000804','00000000-0000-4000-8000-000000000801',1,94000000);
insert into gift_events(id,room_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000804','00000000-0000-4000-8000-000000000801',1,94000000) on conflict do nothing;
insert into gift_events(room_id,quantity,total_coins) values(null,1,999999999);
do $$ begin
 if (select count(*) from room_diamond_blast_events)<>5 or (select total_coins from nimzo_private.room_diamond_cycles where room_id='00000000-0000-4000-8000-000000000801')<>100000000 then raise exception 'multi-stage or replay'; end if;
 if exists(select 1 from room_diamond_blast_events where stage=0) then raise exception 'historical stage emitted'; end if;
end $$;
savepoint settlement;
insert into gift_events(room_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000802',1,100000000);
rollback to settlement;
do $$ begin if exists(select 1 from room_diamond_blast_events where room_id='00000000-0000-4000-8000-000000000802') or exists(select 1 from nimzo_private.room_diamond_cycles where room_id='00000000-0000-4000-8000-000000000802') then raise exception 'rollback leaked progress'; end if; end $$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000801';
do $$ declare s jsonb; begin
 s:=room_diamond_status('00000000-0000-4000-8000-000000000801');
 if (s->>'completed_stages')::int<>6 or (s->>'active_stage')::int<>5 or (s->>'progress')::numeric<>1 then raise exception 'final cap'; end if;
 if (select count(*) from room_diamond_blast_events)<>5 then raise exception 'member events read'; end if;
 begin delete from room_diamond_blast_events; raise exception 'FAIL event deletion'; exception when insufficient_privilege then null; end;
 begin update room_diamond_blast_events set stage=0; raise exception 'FAIL event mutation'; exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000802';
do $$ begin if (select count(*) from room_diamond_blast_events)<>0 then raise exception 'cross room events'; end if; end $$;
set local request.jwt.claim.sub='';
do $$ begin begin perform room_diamond_status('00000000-0000-4000-8000-000000000801'); raise exception 'FAIL anonymous status'; exception when invalid_authorization_specification then null; end; end $$;
reset role;
-- Existing server settlement/retry remains the only way clients advance progress.
insert into gifts(id,name,category,coin_price) values('00000000-0000-4000-8000-000000000805','Diamond fixture','test',5000000);
update wallets set coins=20000000 where user_id='00000000-0000-4000-8000-000000000801';
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000801';
select send_gift('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000805',1,'diamond-settlement');
select send_gift('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000805',1,'diamond-settlement');
reset role;
do $$ begin
 if (select coins from wallets where user_id='00000000-0000-4000-8000-000000000801')<>15000000 or (select count(*) from ledger where idempotency_key like 'diamond-settlement:%')<>2 then raise exception 'economics changed'; end if;
 if (select total_coins from nimzo_private.room_diamond_cycles where room_id='00000000-0000-4000-8000-000000000801')<>105000000 or (select count(*) from room_diamond_blast_events)<>5 then raise exception 'settlement replay counted'; end if;
 if has_table_privilege('anon','public.room_diamond_blast_events','SELECT') or has_table_privilege('authenticated','nimzo_private.room_diamond_cycles','SELECT') or has_function_privilege('authenticated','nimzo_private.room_diamond_initialize(uuid,timestamptz,uuid[])','EXECUTE') then raise exception 'private access exposed'; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='room_diamond_blast_events') then raise exception 'Realtime publication missing'; end if;
end $$;
rollback;

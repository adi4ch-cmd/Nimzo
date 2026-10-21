-- Disposable PostgreSQL fixture contract (no real account data).
-- This fixture assumes minimal public tables with the production column types.
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001601',true);
create temporary table honor_initial as select public.my_honor_milestones() result;
do $$ begin
 if jsonb_array_length((select result from honor_initial))<>12 then raise exception 'must return 12 original rules'; end if;
 if exists(select 1 from honor_initial,jsonb_array_elements(result) r where (r->>'earned')::boolean) then raise exception 'empty account earned a medal'; end if;
end $$;
insert into public.gift_events(id,sender_id,receiver_id,total_coins,created_at) values
 ('00000000-0000-4000-8000-000000001610','00000000-0000-4000-8000-000000001601','00000000-0000-4000-8000-000000001602',1000,'2026-10-20T01:00:00Z'),
 ('00000000-0000-4000-8000-000000001611','00000000-0000-4000-8000-000000001601','00000000-0000-4000-8000-000000001601',100000,'2026-10-20T02:00:00Z');
insert into public.ledger(user_id,kind,diamond_delta,ref,created_at) values
 ('00000000-0000-4000-8000-000000001601','profile_gift_received',1000,'{"from":"00000000-0000-4000-8000-000000001602"}','2026-10-20T03:00:00Z'),
 ('00000000-0000-4000-8000-000000001601','gift_received',100000,'{"from":"00000000-0000-4000-8000-000000001601"}','2026-10-20T04:00:00Z'),
 ('00000000-0000-4000-8000-000000001601','admin_credit',100000,'{}','2026-10-20T05:00:00Z');
insert into public.game_rounds(id,status,settled_at) values
 ('00000000-0000-4000-8000-000000001620','settled','2026-10-20T06:00:00Z'),
 ('00000000-0000-4000-8000-000000001621','open',null),
 ('00000000-0000-4000-8000-000000001622','settled','2026-10-20T07:00:00Z');
insert into public.game_bets(id,round_id,user_id,status,settled_at) values
 ('00000000-0000-4000-8000-000000001630','00000000-0000-4000-8000-000000001620','00000000-0000-4000-8000-000000001601','won','2026-10-20T06:00:00Z'),
 ('00000000-0000-4000-8000-000000001631','00000000-0000-4000-8000-000000001620','00000000-0000-4000-8000-000000001601','won','2026-10-20T06:00:00Z'),
 ('00000000-0000-4000-8000-000000001632','00000000-0000-4000-8000-000000001621','00000000-0000-4000-8000-000000001601','won',null),
 ('00000000-0000-4000-8000-000000001633','00000000-0000-4000-8000-000000001622','00000000-0000-4000-8000-000000001601','refunded','2026-10-20T07:00:00Z');
insert into public.rooms(id,owner_id,created_at) values
 ('00000000-0000-4000-8000-000000001640','00000000-0000-4000-8000-000000001601','2026-10-20T08:00:00Z');
create temporary table honor_after as select public.my_honor_milestones() result;
do $$ declare rows jsonb; begin
 select result into rows from honor_after;
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'code'='first_gift' and (r->>'progress')::bigint=1 and (r->>'earned')::boolean and (r->>'earned_at')::timestamptz='2026-10-20T01:00:00Z') then raise exception 'first gift must use real nonself event timestamp'; end if;
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'code'='gift_coins_1000' and (r->>'progress')::bigint=1000 and (r->>'earned')::boolean) then raise exception 'gift coin threshold'; end if;
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'code'='gift_diamonds_10000' and (r->>'progress')::bigint=1000 and not (r->>'earned')::boolean and r->>'earned_at' is null) then raise exception 'self and nongift credits must not inflate eligibility'; end if;
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'code'='rounds_1' and (r->>'progress')::bigint=1 and (r->>'earned_at')::timestamptz='2026-10-20T06:00:00Z') then raise exception 'count distinct settled nonrefunded rounds only'; end if;
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'code'='wins_1' and (r->>'progress')::bigint=1 and (r->>'earned')::boolean) then raise exception 'winning round threshold'; end if;
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'code'='room_owner' and (r->>'progress')::bigint=1 and (r->>'earned_at')::timestamptz='2026-10-20T08:00:00Z') then raise exception 'own room milestone'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001602',true);
do $$ begin
 if exists(select 1 from jsonb_array_elements(public.my_honor_milestones()) r where (r->>'earned')::boolean) then raise exception 'cross account milestone leak'; end if;
end $$;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 begin perform public.my_honor_milestones(); raise exception 'unauthenticated honors allowed'; exception when invalid_authorization_specification then null; end;
end $$;
select 'PASS twelve honor rules, empty state, actual gift/credit thresholds, self exclusion, timestamps, auth';
rollback;

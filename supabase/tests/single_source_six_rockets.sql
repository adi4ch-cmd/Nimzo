-- Disposable fixture only. Real settlement trigger, no fake wallet/paid gifts.
begin;
insert into public.rooms values('00000000-0000-4000-8000-000000007001');
insert into public.room_members values('00000000-0000-4000-8000-000000007001','00000000-0000-4000-8000-000000007002');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000007002',true);
insert into public.gift_events(room_id,total_coins) values('00000000-0000-4000-8000-000000007001',100000000);
do $$begin
 if (select count(*) from public.room_diamond_blast_events)<>6 then raise exception 'six original milestones lost'; end if;
 if public.room_rocket_status_v2('00000000-0000-4000-8000-000000007001')->>'completed_stages'<>'6' then raise exception 'wrong v2 progress'; end if;
end$$;
insert into public.gift_events(room_id,total_coins) values('00000000-0000-4000-8000-000000007001',900000000);
do $$begin
 if (select count(*) from public.room_diamond_blast_events)<>6 then raise exception 'mixed-source milestones emitted'; end if;
 if public.room_rocket_status_v2('00000000-0000-4000-8000-000000007001')->>'completed_stages'<>'6' then raise exception 'six-stage progress changed'; end if;
 if public.room_diamond_status('00000000-0000-4000-8000-000000007001')->>'completed_stages'<>'6' then raise exception 'old APK status changed'; end if;
 if has_function_privilege('anon','public.room_rocket_status_v2(uuid)','EXECUTE') then raise exception 'anonymous status exposed'; end if;
end$$;
insert into public.gift_events(room_id,total_coins) values('00000000-0000-4000-8000-000000007001',10);
do $$begin
 if (select count(*) from public.room_diamond_blast_events)<>6 then raise exception 'milestone replayed'; end if;
end$$;
select 'PASS six single-source stages, no extra stages at 1B, original API compatibility, no replay';
rollback;

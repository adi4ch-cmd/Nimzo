begin;
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',false);
select set_config('request.jwt.claims','{"session_id":"00000000-0000-4000-8000-000000000401"}',false);
select public.set_presence(true);
select set_config('request.jwt.claims','{"session_id":"00000000-0000-4000-8000-000000000402"}',false);
select public.set_presence(true);
select set_config('request.jwt.claims','{"session_id":"00000000-0000-4000-8000-000000000401"}',false);
select public.set_presence(false);
do $$begin
 if not (select is_online from public.presence_status(array['00000000-0000-4000-8000-000000000101'::uuid])) then raise exception 'second device presence lost'; end if;
 begin
 perform * from nimzo_private.presence_sessions;
 raise exception 'private sessions exposed';
 exception when insufficient_privilege then null; end;
end$$;
reset role;
update nimzo_private.presence_sessions set last_seen_at=clock_timestamp()-interval '2 minutes';
set role authenticated;
do $$begin
 if (select is_online from public.presence_status(array['00000000-0000-4000-8000-000000000101'::uuid])) then raise exception 'stale session online'; end if;
end$$;
reset role;
insert into public.blocks(blocker_id,blocked_id) values ('00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000101');
set role authenticated;
do $$begin
 if exists(select 1 from public.presence_status(array['00000000-0000-4000-8000-000000000102'::uuid])) then raise exception 'blocked-by user presence exposed'; end if;
end$$;
reset role;
set role anon;
do $$begin
 begin
 perform public.presence_status(array['00000000-0000-4000-8000-000000000101'::uuid]);
 raise exception 'anonymous presence exposed';
 exception when insufficient_privilege then null; end;
end$$;
reset role;
rollback;

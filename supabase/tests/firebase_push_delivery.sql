begin;
-- Production auth.sessions is supplied by Supabase, never created by migration.
insert into auth.sessions(id,user_id) values
 ('00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000101'),
 ('00000000-0000-4000-8000-000000000502','00000000-0000-4000-8000-000000000102');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
select set_config('request.jwt.claims','{"session_id":"00000000-0000-4000-8000-000000000501"}',true);
select public.register_device(repeat('deviceA',20));
reset role;
insert into public.notifications(id,user_id,category,title) values
 ('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000101','system','Test');
update nimzo_private.push_outbox set attempts=4 where notification_id='00000000-0000-4000-8000-000000000601';
set local role authenticated;
do $$begin
 begin
 perform * from public.claim_push_batch();
 raise exception 'Authenticated user can claim everyone push';
 exception when insufficient_privilege then null; end;
end$$;
reset role;
set local role service_role;
do $$declare jobs jsonb;begin
 select jsonb_agg(to_jsonb(j)) into jobs from public.claim_push_batch() j;
 if jsonb_array_length(jobs)<>1 or jobs->0->>'notification_id'<>'00000000-0000-4000-8000-000000000601' then raise exception 'Push was not claimed';end if;
 if exists(select 1 from public.claim_push_batch()) then raise exception 'Concurrent lease duplicate';end if;
 if not public.finish_push((jobs->0->>'notification_id')::uuid,jobs->0->>'device_token',(jobs->0->>'lease_id')::uuid,'sent') then raise exception 'Active final retry was prematurely discarded';end if;
end$$;
reset role;
-- Token changes ownership: queued notifications for the old owner must not leak.
insert into public.notifications(id,user_id,category) values
 ('00000000-0000-4000-8000-000000000602','00000000-0000-4000-8000-000000000101','system');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
select set_config('request.jwt.claims','{"session_id":"00000000-0000-4000-8000-000000000502"}',true);
select public.register_device(repeat('deviceA',20));
reset role;
set local role service_role;
do $$begin if exists(select 1 from public.claim_push_batch()) then raise exception 'Old account notification leaked';end if;end$$;
reset role;
insert into public.notifications(user_id,category) select '00000000-0000-4000-8000-000000000102','system' from generate_series(1,6);
set local role service_role;
do $$declare batch_count int;begin
 select count(*) into batch_count from public.claim_push_batch();
 if batch_count<>5 then raise exception 'Push batch must fit inside lease: expected5, got%',batch_count;end if;
 select count(*) into batch_count from public.claim_push_batch();
 if batch_count<>1 then raise exception 'Leased jobs claimed twice';end if;
end$$;
reset role;
insert into public.notifications(id,user_id,category) values
 ('00000000-0000-4000-8000-000000000603','00000000-0000-4000-8000-000000000102','system');
-- Revoked/expired sessions cannot receive pushes even if a phone token survives.
update auth.sessions set not_after=now()-interval '1 second' where id='00000000-0000-4000-8000-000000000502';
set local role service_role;
do $$begin if exists(select 1 from public.claim_push_batch()) then raise exception 'Expired session received push';end if;end$$;
reset role;
set local role authenticated;
do $$begin
 begin perform * from nimzo_private.fcm_devices;raise exception 'Device tokens exposed';
 exception when insufficient_privilege then null;end;
end$$;
select public.unregister_device();
reset role;
do $$begin if exists(select 1 from nimzo_private.fcm_devices) then raise exception 'Logout retained device';end if;end$$;
set local role anon;
do $$begin
 begin perform public.register_device(repeat('deviceX',20));raise exception 'Anonymous registration allowed';
 exception when insufficient_privilege then null;end;
end$$;
reset role;
rollback;

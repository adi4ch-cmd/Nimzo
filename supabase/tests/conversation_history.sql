begin;
-- Disposable schema clone only: synthetic users from social_baseline.sql.
insert into public.messages(sender_id,receiver_id,body) values
 ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000102','forward'),
 ('00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000101','reply'),
 ('00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000103','other conversation');
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',false);
do $$begin
 if (select count(*) from public.messages where conversation_key='00000000-0000-4000-8000-000000000101:00000000-0000-4000-8000-000000000102')<>2 then
  raise exception 'two-way conversation key lost messages'; end if;
 if (select count(*) from public.messages)<>2 then raise exception 'another conversation leaked'; end if;
end$$;
reset role;

rollback;

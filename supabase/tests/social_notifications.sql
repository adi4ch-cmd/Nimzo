begin;
insert into public.follows(follower_id,followee_id) values ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000102');
do $$begin
 if (select count(*) from public.notifications where event_type='follow' and user_id='00000000-0000-4000-8000-000000000102')<>1 then raise exception 'follow did not notify'; end if;
end$$;
insert into public.friendships(requester_id,addressee_id) values ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000102');
update public.friendships set status='accepted';
update public.friendships set status='accepted';
insert into public.couple_requests(requester_id,addressee_id) values ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000102');
update public.couple_requests set status='accepted';
do $$begin
 if (select count(*) from public.notifications where event_type='friend_accepted')<>1 then raise exception 'accepted notification duplicated'; end if;
 if (select count(*) from public.notifications where event_type in ('cp_request','cp_accepted'))<>2 then raise exception 'CP notifications missing'; end if;
end$$;
insert into public.blocks(blocker_id,blocked_id) values ('00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000101');
insert into public.follows(follower_id,followee_id) values ('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000103');
do $$begin
 if exists(select 1 from public.notifications where user_id='00000000-0000-4000-8000-000000000103') then raise exception 'blocked actor notified'; end if;
end$$;
select set_config('test.notice_id',(select id::text from public.notifications where event_type='follow' limit 1),false);
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000103',false);
do $$begin
 if exists(select 1 from public.notifications where user_id='00000000-0000-4000-8000-000000000102') then raise exception 'notifications leaked'; end if;
 if public.mark_notification_read(current_setting('test.notice_id')::uuid) then raise exception 'marked another user notice'; end if;
end$$;
reset role;
do $$begin
 if exists(select 1 from public.notifications where id=current_setting('test.notice_id')::uuid and read_at is not null) then raise exception 'another user notice changed'; end if;
end$$;
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',false);
do $$declare notice uuid; begin
 select id into notice from public.notifications where event_type='follow';
 if not public.mark_notification_read(notice) then raise exception 'own notice not marked read'; end if;
 if not exists(select 1 from public.notifications where id=notice and read_at is not null) then raise exception 'read timestamp missing'; end if;
end$$;
reset role;
rollback;

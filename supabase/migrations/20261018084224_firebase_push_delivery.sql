-- Android FCM delivery only; no rewards, wallets, games or voice changes.
create table nimzo_private.fcm_devices (
 token text primary key check(length(token) between 40 and 4096),
 user_id uuid not null references public.profiles(id) on delete cascade,
 session_id uuid not null references auth.sessions(id) on delete cascade,
 updated_at timestamptz not null default now()
);
create index fcm_devices_user on nimzo_private.fcm_devices(user_id);
alter table nimzo_private.fcm_devices enable row level security;
revoke all on nimzo_private.fcm_devices from public,anon,authenticated;
grant all on nimzo_private.fcm_devices to service_role;
create policy fcm_backend on nimzo_private.fcm_devices for all to service_role using(true) with check(true);
create function nimzo_private.register_device(p_token text) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); sid uuid:=nullif(auth.jwt()->>'session_id','')::uuid;
begin
 if uid is null or sid is null or not exists(select 1 from public.profiles where id=uid and status='active')
 or not exists(select 1 from auth.sessions where id=sid and user_id=uid and (not_after is null or not_after>now())) then
 raise exception 'Active session required' using errcode='42501';end if;
 if p_token is null or length(p_token) not between 40 and 4096 or p_token !~ '^[a-zA-Z0-9:_-]+$' then
 raise exception 'Invalid device token' using errcode='22023';end if;
 delete from nimzo_private.fcm_devices where user_id=uid and session_id=sid and token<>p_token;
 insert into nimzo_private.fcm_devices(token,user_id,session_id) values(p_token,uid,sid)
 on conflict(token) do update set user_id=excluded.user_id,session_id=excluded.session_id,updated_at=now();
end$$;
revoke all on function nimzo_private.register_device(text) from public,anon;
grant execute on function nimzo_private.register_device(text) to authenticated;
create or replace function public.register_device(p_token text) returns void
language sql security invoker set search_path='' as $$select nimzo_private.register_device(p_token)$$;
revoke all on function public.register_device(text) from public,anon;
grant execute on function public.register_device(text) to authenticated;
create function nimzo_private.unregister_device() returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 delete from nimzo_private.fcm_devices where user_id=auth.uid() and session_id=nullif(auth.jwt()->>'session_id','')::uuid;
end$$;
revoke all on function nimzo_private.unregister_device() from public,anon;
grant execute on function nimzo_private.unregister_device() to authenticated;
create function public.unregister_device() returns void language sql security invoker set search_path='' as $$select nimzo_private.unregister_device()$$;
revoke all on function public.unregister_device() from public,anon;
grant execute on function public.unregister_device() to authenticated;

create table nimzo_private.push_outbox (
 notification_id uuid not null references public.notifications(id) on delete cascade,
 device_token text not null references nimzo_private.fcm_devices(token) on delete cascade,
 status text not null default 'pending' check(status in ('pending','sent','skipped','failed')),
 attempts int not null default 0,
 available_at timestamptz not null default now(),
 locked_until timestamptz,
 lease_id uuid,
 created_at timestamptz not null default now(),
 primary key(notification_id,device_token)
);
create index push_outbox_ready on nimzo_private.push_outbox(available_at) where status='pending';
alter table nimzo_private.push_outbox enable row level security;
revoke all on nimzo_private.push_outbox from public,anon,authenticated;
grant all on nimzo_private.push_outbox to service_role;
create policy push_backend on nimzo_private.push_outbox for all to service_role using(true) with check(true);
create function nimzo_private.queue_push() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into nimzo_private.push_outbox(notification_id,device_token)
 select new.id,d.token from nimzo_private.fcm_devices d join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
 where d.user_id=new.user_id and (s.not_after is null or s.not_after>now()) and new.read_at is null;
 return new;
end$$;
revoke all on function nimzo_private.queue_push() from public,anon,authenticated;
create trigger queue_fcm_push after insert on public.notifications for each row execute function nimzo_private.queue_push();

create function nimzo_private.claim_push_batch() returns table(notification_id uuid,device_token text,user_id uuid,lease_id uuid)
language plpgsql security definer set search_path='' as $$
begin
 update nimzo_private.push_outbox q set status='skipped' where q.status='pending' and
 ((q.attempts>=5 and (q.locked_until is null or q.locked_until<now())) or q.created_at<now()-interval '24 hours' or not exists(
 select 1 from public.notifications n join nimzo_private.fcm_devices d on d.user_id=n.user_id and d.token=q.device_token
 join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
 join public.profiles p on p.id=d.user_id and p.status='active'
 where n.id=q.notification_id and n.read_at is null and (s.not_after is null or s.not_after>now())
 and not exists(select 1 from public.user_preferences pref where pref.user_id=n.user_id and
 ((n.category='messages' and not pref.message_notifications) or (n.category='gifts' and not pref.gift_notifications)))
 and not exists(select 1 from public.blocks b where n.actor_id is not null and
 ((b.blocker_id=n.user_id and b.blocked_id=n.actor_id) or (b.blocker_id=n.actor_id and b.blocked_id=n.user_id)))));
 return query with candidates as (
 select q.notification_id,q.device_token from nimzo_private.push_outbox q where q.status='pending' and q.available_at<=now()
 and (q.locked_until is null or q.locked_until<now()) order by q.available_at limit 5 for update skip locked
 ), leased as (
 update nimzo_private.push_outbox q set attempts=q.attempts+1,locked_until=now()+interval '3 minutes',lease_id=gen_random_uuid()
 from candidates c where q.notification_id=c.notification_id and q.device_token=c.device_token
 returning q.notification_id,q.device_token,q.lease_id)
 select l.notification_id,l.device_token,n.user_id,l.lease_id from leased l join public.notifications n on n.id=l.notification_id;
end$$;
revoke all on function nimzo_private.claim_push_batch() from public,anon,authenticated;
grant execute on function nimzo_private.claim_push_batch() to service_role;
create function public.claim_push_batch() returns table(notification_id uuid,device_token text,user_id uuid,lease_id uuid)
language sql security invoker set search_path='' as $$select * from nimzo_private.claim_push_batch()$$;
revoke all on function public.claim_push_batch() from public,anon,authenticated;
grant execute on function public.claim_push_batch() to service_role;
create function nimzo_private.finish_push(p_id uuid,p_token text,p_lease uuid,p_result text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if p_result not in ('sent','retry','invalid') or p_result is null then raise exception 'Invalid result' using errcode='22023';end if;
 update nimzo_private.push_outbox set status=case when p_result='sent' then 'sent' when p_result='invalid' then 'skipped' when attempts>=5 then 'failed' else 'pending' end,
 locked_until=null,available_at=now()+interval '1 minute'*power(2,least(attempts,5))
 where notification_id=p_id and device_token=p_token and lease_id=p_lease and status='pending';
 if not found then return false;end if;
 if p_result='invalid' then
 delete from nimzo_private.fcm_devices d using public.notifications n where n.id=p_id and d.user_id=n.user_id and d.token=p_token;
 end if;
 return true;
end$$;
revoke all on function nimzo_private.finish_push(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function nimzo_private.finish_push(uuid,text,uuid,text) to service_role;
create function public.finish_push(p_id uuid,p_token text,p_lease uuid,p_result text) returns boolean
language sql security invoker set search_path='' as $$select nimzo_private.finish_push(p_id,p_token,p_lease,p_result)$$;
revoke all on function public.finish_push(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.finish_push(uuid,text,uuid,text) to service_role;
grant usage on schema nimzo_private to service_role;
notify pgrst,'reload schema';

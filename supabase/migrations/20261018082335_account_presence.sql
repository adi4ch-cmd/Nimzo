-- Session-scoped ephemeral presence. No wallets, games or voice changes.
create table nimzo_private.presence_sessions (
 user_id uuid not null references public.profiles(id) on delete cascade,
 session_id uuid not null,
 is_online boolean not null,
 last_seen_at timestamptz not null default clock_timestamp(),
 primary key(user_id,session_id)
);
alter table nimzo_private.presence_sessions enable row level security;
revoke all on nimzo_private.presence_sessions from public,anon,authenticated;
create policy presence_backend_only on nimzo_private.presence_sessions for all to service_role using(true) with check(true);

create function nimzo_private.set_presence(p_online boolean) returns boolean
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); session uuid;
begin
 if uid is null or not exists(select 1 from public.profiles where id=uid and status='active') then
  raise exception 'Active account required' using errcode='42501'; end if;
 session=nullif(auth.jwt()->>'session_id','')::uuid;
 if session is null or p_online is null then raise exception 'Valid session required' using errcode='42501'; end if;
 insert into nimzo_private.presence_sessions(user_id,session_id,is_online,last_seen_at)
 values(uid,session,p_online,clock_timestamp())
 on conflict(user_id,session_id) do update set is_online=excluded.is_online,last_seen_at=excluded.last_seen_at;
 return true;
end $$;
revoke all on function nimzo_private.set_presence(boolean) from public,anon;
grant execute on function nimzo_private.set_presence(boolean) to authenticated;
create function public.set_presence(p_online boolean) returns boolean
language sql security invoker set search_path='' as $$select nimzo_private.set_presence(p_online)$$;
revoke all on function public.set_presence(boolean) from public,anon;
grant execute on function public.set_presence(boolean) to authenticated;

create function nimzo_private.presence_status(p_users uuid[]) returns table(user_id uuid,is_online boolean)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and status='active') then
  raise exception 'Active account required' using errcode='42501'; end if;
 if p_users is null or cardinality(p_users)>100 then raise exception 'Request at most 100 profiles' using errcode='22023'; end if;
 return query select p.id,bool_or(s.is_online and s.last_seen_at>clock_timestamp()-interval '90 seconds')
 from (select distinct unnest(p_users) id) requested
 join public.profiles p on p.id=requested.id and p.status='active'
 left join nimzo_private.presence_sessions s on s.user_id=p.id
 where not exists(select 1 from public.blocks b where
  (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
 group by p.id;
end $$;
revoke all on function nimzo_private.presence_status(uuid[]) from public,anon;
grant execute on function nimzo_private.presence_status(uuid[]) to authenticated;
create function public.presence_status(p_users uuid[]) returns table(user_id uuid,is_online boolean)
language sql security invoker set search_path='' as $$select * from nimzo_private.presence_status(p_users)$$;
revoke all on function public.presence_status(uuid[]) from public,anon;
grant execute on function public.presence_status(uuid[]) to authenticated;
notify pgrst,'reload schema';

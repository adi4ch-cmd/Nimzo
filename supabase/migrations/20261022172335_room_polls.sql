begin;
create table public.room_polls(
 id uuid primary key default gen_random_uuid(),room_id uuid not null references public.rooms(id),
 creator_id uuid not null references public.profiles(id),question text not null check(length(question) between 1 and 120),
 options text[] not null check(array_length(options,1) between 2 and 4),
 client_key text not null,created_at timestamptz not null default now(),
 ends_at timestamptz not null default(now()+interval '5 minutes'),closed_at timestamptz,
 revision bigint not null default 1,unique(creator_id,client_key)
);
create unique index room_polls_one_open on public.room_polls(room_id) where closed_at is null;
create index room_polls_room_time on public.room_polls(room_id,created_at desc);
create table public.room_poll_votes(
 poll_id uuid not null references public.room_polls(id),user_id uuid not null references public.profiles(id),
 choice integer not null check(choice between 0 and 3),created_at timestamptz not null default now(),primary key(poll_id,user_id)
);
create index room_poll_vote_counts on public.room_poll_votes(poll_id,choice);
create index room_poll_vote_user on public.room_poll_votes(user_id);
alter table public.room_polls enable row level security;
alter table public.room_poll_votes enable row level security;
revoke all on public.room_polls,public.room_poll_votes from public,anon,authenticated;
grant select(id,room_id,creator_id,question,options,created_at,ends_at,closed_at,revision) on public.room_polls to authenticated;
grant select on public.room_poll_votes to authenticated;
create function public.can_view_room_poll(p_room uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.room_members m join public.rooms r on r.id=m.room_id
 join public.profiles p on p.id=m.user_id where m.room_id=p_room and m.user_id=auth.uid() and r.status='open' and p.status='active'
 and not exists(select 1 from public.room_bans b where b.room_id=p_room and b.user_id=auth.uid()))
$$;
revoke all on function public.can_view_room_poll(uuid) from public,anon;
grant execute on function public.can_view_room_poll(uuid) to authenticated;
create policy room_polls_joined on public.room_polls for select to authenticated using(public.can_view_room_poll(room_id));
create policy room_poll_own_vote on public.room_poll_votes for select to authenticated using(user_id=(select auth.uid()));

create function public.create_room_poll(p_room uuid,p_question text,p_options text[],p_key text,p_expected_user uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();existing public.room_polls;opts text[];q text:=trim(p_question);r public.rooms;pid uuid;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if p_expected_user is distinct from u then raise exception 'POLL_ACCOUNT_CHANGED' using errcode='22023';end if;
 if q is null or length(q) not between 1 and 120 or cardinality(p_options) not between 2 and 4 or p_options is null
 or nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'INVALID_POLL' using errcode='22023';end if;
 select array_agg(trim(x) order by ord) into opts from unnest(p_options) with ordinality a(x,ord);
 if exists(select 1 from unnest(opts)x where x is null or length(x) not between 1 and 60)
 or (select count(distinct lower(x)) from unnest(opts)x)<>cardinality(opts) then raise exception 'INVALID_POLL_OPTIONS' using errcode='22023';end if;
 -- Lock both keys: retries across rooms and competing creators in one room.
 perform pg_advisory_xact_lock(hashtextextended('poll-user:'||u::text||':'||p_key,0));
 select * into existing from public.room_polls where creator_id=u and client_key=p_key;
 if found then
  if existing.room_id is distinct from p_room or existing.question is distinct from q or existing.options is distinct from opts then raise exception 'POLL_PAYLOAD_MISMATCH' using errcode='22023';end if;
  return existing.id;
 end if;
 if not public.can_view_room_poll(p_room) then raise exception 'ROOM_MEMBERSHIP_REQUIRED';end if;
 select * into r from public.rooms where id=p_room for share;
 if not r.perm_chat or not public.room_allows(p_room,u,r.chat_permission) then raise exception 'ROOM_CHAT_DISABLED';end if;
 perform pg_advisory_xact_lock(hashtextextended('poll-room:'||p_room::text,0));
 update public.room_polls set closed_at=ends_at,revision=revision+1 where room_id=p_room and closed_at is null and ends_at<=clock_timestamp();
 if exists(select 1 from public.room_polls where room_id=p_room and closed_at is null) then raise exception 'POLL_ALREADY_ACTIVE';end if;
 insert into public.room_polls(room_id,creator_id,question,options,client_key) values(p_room,u,q,opts,p_key) returning id into pid;
 return pid;
end$$;
create function public.cast_room_vote(p_poll uuid,p_choice integer,p_expected_user uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p public.room_polls;prior integer;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if p_expected_user is distinct from u then raise exception 'POLL_ACCOUNT_CHANGED' using errcode='22023';end if;
 select * into p from public.room_polls where id=p_poll for update;
 if not found then raise exception 'POLL_NOT_FOUND';end if;
 if not public.can_view_room_poll(p.room_id) then raise exception 'ROOM_MEMBERSHIP_REQUIRED';end if;
 select choice into prior from public.room_poll_votes where poll_id=p_poll and user_id=u;
 if found then
  if prior is distinct from p_choice then raise exception 'VOTE_ALREADY_CAST';end if;
  return jsonb_build_object('choice',prior,'duplicate',true);
 end if;
 if p.closed_at is not null or p.ends_at<=clock_timestamp() then raise exception 'POLL_CLOSED';end if;
 if p_choice is null or p_choice<0 or p_choice>=cardinality(p.options) then raise exception 'INVALID_POLL_CHOICE' using errcode='22023';end if;
 insert into public.room_poll_votes(poll_id,user_id,choice) values(p_poll,u,p_choice);
 update public.room_polls set revision=revision+1 where id=p_poll;
 return jsonb_build_object('choice',p_choice,'duplicate',false);
end$$;
create function public.close_room_poll(p_poll uuid,p_expected_user uuid) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p public.room_polls;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if p_expected_user is distinct from u then raise exception 'POLL_ACCOUNT_CHANGED' using errcode='22023';end if;
 select * into p from public.room_polls where id=p_poll for update;
 if not found then raise exception 'POLL_NOT_FOUND';end if;
 if not public.can_view_room_poll(p.room_id) then raise exception 'ROOM_MEMBERSHIP_REQUIRED';end if;
 if p.creator_id<>u and not public.can_moderate(p.room_id,u) then raise exception 'POLL_CLOSE_DENIED';end if;
 if p.closed_at is null then update public.room_polls set closed_at=clock_timestamp(),revision=revision+1 where id=p_poll;end if;
end$$;
create function public.room_poll_state(p_room uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if not public.can_view_room_poll(p_room) then raise exception 'ROOM_MEMBERSHIP_REQUIRED';end if;
 select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) into result from (
  select p.id,p.creator_id,p.question,p.options,p.created_at,p.ends_at,
   (p.closed_at is null and p.ends_at>now()) as active,
   (p.creator_id=auth.uid() or public.can_moderate(p.room_id,auth.uid())) as can_close,
   (select v.choice from public.room_poll_votes v where v.poll_id=p.id and v.user_id=auth.uid()) as my_choice,
   (select jsonb_agg((select count(*) from public.room_poll_votes v where v.poll_id=p.id and v.choice=i-1) order by i) from generate_subscripts(p.options,1)i) as counts
  from public.room_polls p where p.room_id=p_room order by p.created_at desc limit 10
 )x;
 return result;
end$$;
revoke all on function public.create_room_poll(uuid,text,text[],text,uuid),public.cast_room_vote(uuid,integer,uuid),public.close_room_poll(uuid,uuid),public.room_poll_state(uuid) from public,anon,authenticated;
grant execute on function public.create_room_poll(uuid,text,text[],text,uuid),public.cast_room_vote(uuid,integer,uuid),public.close_room_poll(uuid,uuid),public.room_poll_state(uuid) to authenticated;
do $$begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table public.room_polls;end if;end$$;
notify pgrst,'reload schema';
commit;

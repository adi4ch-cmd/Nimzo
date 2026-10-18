-- NIMZO non-monetary PK room-to-room challenge system.
-- Voice microphone count and established gift/ledger settlement are untouched.
-- Scores are derived ONLY from verified gift_events during the match period.
create table if not exists public.room_pk_invites (
  id uuid primary key default gen_random_uuid(),
  challenger_room uuid not null references public.rooms(id),
  challenged_room uuid not null references public.rooms(id),
  requested_by uuid not null references auth.users(id),
  status text not null default 'pending'
    check (status in ('pending','accepted','declined','cancelled','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  responded_at timestamptz,
  constraint pk_invite_distinct_rooms check (challenger_room <> challenged_room)
);

create index if not exists room_pk_invites_from_idx on public.room_pk_invites(challenger_room,created_at desc);
create index if not exists room_pk_invites_to_idx on public.room_pk_invites(challenged_room,created_at desc);

create table if not exists public.room_pk_matches (
  id uuid primary key default gen_random_uuid(),
  room_a uuid not null references public.rooms(id),
  room_b uuid not null references public.rooms(id),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_by uuid not null references auth.users(id),
  invite_id uuid not null unique references public.room_pk_invites(id),
  constraint pk_match_distinct_rooms check (room_a <> room_b),
  constraint pk_match_duration check (ends_at > started_at and ends_at <= started_at + interval '10 minutes')
);
create index if not exists room_pk_matches_active_end_idx on public.room_pk_matches(ends_at desc);
create index if not exists room_pk_matches_a_idx on public.room_pk_matches(room_a,ends_at desc);
create index if not exists room_pk_matches_b_idx on public.room_pk_matches(room_b,ends_at desc);
create index if not exists gift_events_pk_score_idx on public.gift_events(room_id,created_at);

alter table public.room_pk_invites enable row level security;
alter table public.room_pk_matches enable row level security;
revoke all on public.room_pk_invites, public.room_pk_matches from anon, authenticated;
grant select on public.room_pk_invites, public.room_pk_matches to authenticated;
drop policy if exists room_pk_invites_owner_read on public.room_pk_invites;
create policy room_pk_invites_owner_read
on public.room_pk_invites for select to authenticated using (
  requested_by = auth.uid() or
  exists (select 1 from public.rooms r where r.id=challenged_room and r.owner_id=auth.uid())
);
drop policy if exists room_pk_matches_public_read on public.room_pk_matches;
create policy room_pk_matches_public_read on public.room_pk_matches
for select to authenticated using (
  exists (select 1 from public.rooms ra, public.rooms rb
    where ra.id=room_a and rb.id=room_b and ra.is_private=false
      and rb.is_private=false and ra.status='open' and rb.status='open')
);

-- Checks that a public room owner can invite another public room.
create or replace function public.pk_invite(p_from_room uuid,p_to_room uuid)
returns uuid
language plpgsql security definer set search_path = public,pg_temp
as $$
declare
  u uuid := auth.uid();
  new_id uuid;
begin
  if u is null then raise exception 'Sign in required' using errcode='28000'; end if;
  if p_from_room is null or p_to_room is null or p_from_room=p_to_room then
    raise exception 'Choose two different public rooms'; end if;
  -- Serialize actions that originate from the same room.
  perform pg_advisory_xact_lock(hashtextextended('pk_room:'||p_from_room::text,0));
  if not exists (select 1 from public.rooms where id=p_from_room
      and owner_id=u and is_private=false and status='open') then
    raise exception 'Only the public room owner can challenge'; end if;
  if not exists (select 1 from public.rooms where id=p_to_room
      and is_private=false and status='open') then
    raise exception 'Destination room unavailable'; end if;
  if exists (select 1 from public.room_pk_matches m
     where m.ends_at>now() and
      (m.room_a in (p_from_room,p_to_room) or m.room_b in (p_from_room,p_to_room))) then
    raise exception 'One of the rooms is already in PK'; end if;

  update public.room_pk_invites set status='expired',responded_at=now()
    where challenger_room=p_from_room and challenged_room=p_to_room
      and status='pending' and expires_at<=now();
  if exists (select 1 from public.room_pk_invites
    where challenger_room=p_from_room and challenged_room=p_to_room
      and status='pending' and expires_at>now()) then
    raise exception 'Invite already pending'; end if;
  insert into public.room_pk_invites(challenger_room,challenged_room,requested_by)
    values(p_from_room,p_to_room,u) returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.pk_respond(p_invite uuid,p_accept boolean)
returns uuid
language plpgsql security definer set search_path = public,pg_temp
as $$
declare
  u uuid:=auth.uid();
  inv public.room_pk_invites%rowtype;
  match_id uuid;
  first_room uuid;
  second_room uuid;
begin
  if u is null then raise exception 'Sign in required' using errcode='28000'; end if;
  if p_invite is null or p_accept is null then raise exception 'Invalid response'; end if;
  select * into inv from public.room_pk_invites where id=p_invite for update;
  if not found then raise exception 'PK invitation unavailable'; end if;
  if inv.status<>'pending' or inv.expires_at<=now() then
    raise exception 'PK invitation expired or resolved'; end if;
  if not exists(select 1 from public.rooms
      where id=inv.challenged_room and owner_id=u
        and status='open' and is_private=false) then
    raise exception 'Only the invited public room owner may respond'; end if;
  if not p_accept then
    update public.room_pk_invites set status='declined',responded_at=now()
      where id=inv.id;
    return null;
  end if;

  -- Consistent locking order avoids concurrent cross-challenge races.
  first_room:=least(inv.challenger_room,inv.challenged_room);
  second_room:=greatest(inv.challenger_room,inv.challenged_room);
  perform pg_advisory_xact_lock(hashtextextended('pk_room:'||first_room::text,0));
  perform pg_advisory_xact_lock(hashtextextended('pk_room:'||second_room::text,0));
  if not exists(select 1 from public.rooms
      where id=inv.challenger_room and status='open' and is_private=false) then
    raise exception 'Challenger room is not public/open'; end if;
  if exists(select 1 from public.room_pk_matches m
     where m.ends_at>now() and
      (m.room_a in(inv.challenger_room,inv.challenged_room)
       or m.room_b in(inv.challenger_room,inv.challenged_room))) then
    raise exception 'One room is already in PK'; end if;
  insert into public.room_pk_matches(room_a,room_b,started_at,ends_at,created_by,invite_id)
    values(inv.challenger_room,inv.challenged_room,now(),now()+interval '5 minutes',u,inv.id)
    returning id into match_id;
  update public.room_pk_invites set status='accepted',responded_at=now()
    where id=inv.id;
  return match_id;
end;
$$;

-- Scoreboard: only real gift_events committed by the send_gift RPC count.
create or replace function public.pk_live_board()
returns table(
  match_id uuid, room_a uuid, room_b uuid,
  name_a text, name_b text, number_a bigint, number_b bigint,
  avatar_a text, avatar_b text,
  score_a bigint, score_b bigint, started_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = public,pg_temp
as $$
  select m.id,m.room_a,m.room_b,
    ra.name,rb.name,ra.room_no,rb.room_no,
    ra.avatar_path,rb.avatar_path,
    (select coalesce(sum(g.total_coins),0)::bigint
     from public.gift_events g where g.room_id=m.room_a
       and g.created_at>=m.started_at
       and g.created_at<least(now(),m.ends_at)),
    (select coalesce(sum(g.total_coins),0)::bigint
     from public.gift_events g where g.room_id=m.room_b
       and g.created_at>=m.started_at
       and g.created_at<least(now(),m.ends_at)),
    m.started_at,m.ends_at
  from public.room_pk_matches m
  join public.rooms ra on ra.id=m.room_a
  join public.rooms rb on rb.id=m.room_b
  where auth.uid() is not null and m.ends_at>now()
    and ra.status='open' and rb.status='open'
    and ra.is_private=false and rb.is_private=false
  order by m.started_at desc limit 40;
$$;
revoke all on function public.pk_invite(uuid,uuid) from public,anon;
revoke all on function public.pk_respond(uuid,boolean) from public,anon;
revoke all on function public.pk_live_board() from public,anon;
grant execute on function public.pk_invite(uuid,uuid) to authenticated;
grant execute on function public.pk_respond(uuid,boolean) to authenticated;
grant execute on function public.pk_live_board() to authenticated;

-- Widen the existing structure without replacing occupied, muted or locked rows.
alter table public.mic_seats drop constraint mic_seats_seat_no_check;
alter table public.mic_seats add constraint mic_seats_seat_no_check
  check (seat_no between 1 and 15);

-- Preserve each installation's existing authentication, membership and room guards.
do $$
declare definition text; updated text;
begin
  definition := pg_get_functiondef('public.take_seat(uuid,integer)'::regprocedure);
  updated := regexp_replace(definition, 'p_seat\s*>\s*10', 'p_seat>15', 'g');
  if updated=definition then raise exception 'Unrecognized take_seat range; review before migration'; end if;
  updated := regexp_replace(updated, 'if\s+p_seat\s*<\s*1', 'if p_seat is null or p_seat<1', 'i');
  execute updated;
  definition := pg_get_functiondef('public.create_room(text,text,text)'::regprocedure);
  updated := regexp_replace(definition, 'generate_series\(\s*1\s*,\s*10\s*\)', 'generate_series(1,15)', 'g');
  if updated=definition then raise exception 'Unrecognized create_room seat initializer; review before migration'; end if;
  execute updated;
end $$;

insert into public.mic_seats(room_id,seat_no)
select r.id,seat from public.rooms r cross join generate_series(1,15) seat
on conflict(room_id,seat_no) do nothing;

-- Also cover rooms inserted by administrative tools rather than create_room.
create schema if not exists nimzo_private;
create function nimzo_private.initialize_fifteen_mic_seats() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.mic_seats(room_id,seat_no)
  select new.id,seat from generate_series(1,15) seat
  on conflict(room_id,seat_no) do nothing;
  return new;
end $$;
revoke all on function nimzo_private.initialize_fifteen_mic_seats() from public,anon,authenticated;
create trigger initialize_fifteen_mic_seats after insert on public.rooms
for each row execute function nimzo_private.initialize_fifteen_mic_seats();

create function public.mod_lock_seat(p_room uuid,p_seat integer,p_locked boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise invalid_authorization_specification using message='not authenticated'; end if;
  if not public.can_moderate(p_room,auth.uid()) then raise insufficient_privilege using message='not allowed'; end if;
  if p_seat is null or p_seat not between 1 and 15 or p_locked is null then raise exception 'bad seat'; end if;
  update public.mic_seats set locked=p_locked where room_id=p_room and seat_no=p_seat;
  if not found then raise exception 'seat unavailable'; end if;
end $$;

create or replace function public.mod_mute_seat(p_room uuid,p_seat integer,p_muted boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise invalid_authorization_specification using message='not authenticated'; end if;
  if not public.can_moderate(p_room,auth.uid()) then raise insufficient_privilege using message='not allowed'; end if;
  if p_seat is null or p_seat not between 1 and 15 or p_muted is null then raise exception 'bad seat'; end if;
  update public.mic_seats set muted=p_muted where room_id=p_room and seat_no=p_seat;
  if not found then raise exception 'seat unavailable'; end if;
end $$;

create function public.mod_assign_seat(p_room uuid,p_seat integer,p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare room public.rooms;
begin
  if auth.uid() is null then raise invalid_authorization_specification using message='not authenticated'; end if;
  if not public.can_moderate(p_room,auth.uid()) then raise insufficient_privilege using message='not allowed'; end if;
  if p_seat is null or p_seat not between 1 and 15 or p_user is null then raise exception 'bad seat'; end if;
  -- Serialize with take_seat/leave_room for the target; prevent duplicate seating.
  perform 1 from public.profiles where id=p_user and status='active' for update;
  if not found then raise exception 'account restricted'; end if;
  select * into room from public.rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room and user_id=p_user)
    then raise exception 'join the room first'; end if;
  if exists(select 1 from public.room_bans where room_id=p_room and user_id=p_user)
    then raise exception 'banned from room'; end if;
  if not room.perm_mic and not public.can_moderate(p_room,p_user)
    then raise exception 'mic is turned off in this room'; end if;
  if not public.room_allows(p_room,p_user,room.mic_permission)
    then raise exception 'mic permission required'; end if;
  if exists(select 1 from public.mic_seats where user_id=p_user and room_id<>p_room)
    then raise exception 'already seated'; end if;
  perform 1 from public.mic_seats where room_id=p_room and seat_no=p_seat
    and not locked and (user_id is null or user_id=p_user) for update;
  if not found then raise exception 'seat unavailable'; end if;
  update public.mic_seats set user_id=null,muted=false
    where room_id=p_room and user_id=p_user and seat_no<>p_seat;
  update public.mic_seats set user_id=p_user where room_id=p_room and seat_no=p_seat;
end $$;

revoke all on function public.mod_lock_seat(uuid,integer,boolean) from public,anon;
revoke all on function public.mod_mute_seat(uuid,integer,boolean) from public,anon;
revoke all on function public.mod_assign_seat(uuid,integer,uuid) from public,anon;
grant execute on function public.mod_lock_seat(uuid,integer,boolean) to authenticated;
grant execute on function public.mod_mute_seat(uuid,integer,boolean) to authenticated;
grant execute on function public.mod_assign_seat(uuid,integer,uuid) to authenticated;

-- Room settings, permissions, chat, moderators, themes. All checks are server-side.

alter table rooms add column if not exists rules text;
alter table rooms add column if not exists mic_permission text not null default 'everyone' check (mic_permission in ('everyone','members','mods')),
  add column if not exists chat_permission text not null default 'everyone' check (chat_permission in ('everyone','members','mods')),
  add column if not exists guest_permission text not null default 'everyone' check (guest_permission in ('everyone','members','mods')),
  add column if not exists gift_permission text not null default 'everyone' check (gift_permission in ('everyone','members','mods')),
  add column if not exists music_permission text not null default 'mods' check (music_permission in ('everyone','members','mods')),
  add column if not exists game_permission text not null default 'members' check (game_permission in ('everyone','members','mods')),
  add column if not exists visitor_permission text not null default 'everyone' check (visitor_permission in ('everyone','members','mods'));

-- Direct client updates on rooms are closed; use update_room_settings.
revoke update on rooms from authenticated;

create table if not exists room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  user_id uuid not null references profiles(id),
  body text not null check (char_length(body) between 1 and 300),
  created_at timestamptz not null default now()
);
create index on room_messages (room_id, created_at desc);
alter table room_messages enable row level security;
create policy room_chat_read on room_messages for select to authenticated using (
  exists(select 1 from room_members m where m.room_id=room_messages.room_id and m.user_id=auth.uid())
  or exists(select 1 from rooms r where r.id=room_messages.room_id and r.owner_id=auth.uid()));
revoke insert, update, delete on room_messages from authenticated;

create or replace function room_allows(p_room uuid, p_uid uuid, p_level text) returns boolean
language sql stable security definer set search_path=public as $$
  select case p_level
    when 'everyone' then true
    when 'members'  then exists(select 1 from room_members where room_id=p_room and user_id=p_uid) or exists(select 1 from rooms where id=p_room and owner_id=p_uid)
    else can_moderate(p_room, p_uid) end $$;

create or replace function update_room_settings(p_room uuid, p_settings jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare k text;
begin
  if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) and not is_admin() then raise exception 'only the owner can change settings'; end if;
  if p_settings ? 'theme' and (p_settings->>'theme') not in ('nimzo_white','sage','ocean','lavender','rose','midnight','premium_black','luxury') then raise exception 'bad theme'; end if;
  for k in select jsonb_object_keys(p_settings) loop
    if k not in ('name','country','theme','is_private','rules','mic_permission','chat_permission','guest_permission','gift_permission','music_permission','game_permission','visitor_permission') then
      raise exception 'field not editable: %', k; end if;
  end loop;
  update rooms set
    name = coalesce(p_settings->>'name', name), country = coalesce(p_settings->>'country', country),
    theme = coalesce(p_settings->>'theme', theme), is_private = coalesce((p_settings->>'is_private')::boolean, is_private),
    rules = coalesce(p_settings->>'rules', rules),
    mic_permission = coalesce(p_settings->>'mic_permission', mic_permission), chat_permission = coalesce(p_settings->>'chat_permission', chat_permission),
    guest_permission = coalesce(p_settings->>'guest_permission', guest_permission), gift_permission = coalesce(p_settings->>'gift_permission', gift_permission),
    music_permission = coalesce(p_settings->>'music_permission', music_permission), game_permission = coalesce(p_settings->>'game_permission', game_permission),
    visitor_permission = coalesce(p_settings->>'visitor_permission', visitor_permission)
  where id=p_room;
end $$;

create or replace function set_room_password(p_room uuid, p_password text) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then raise exception 'only the owner can set the password'; end if;
  update rooms set password_hash = case when p_password is null or p_password='' then null else crypt(p_password, gen_salt('bf')) end,
                   is_private = (p_password is not null and p_password<>'') where id=p_room;
end $$;

create or replace function set_moderator(p_room uuid, p_user uuid, p_on boolean) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then raise exception 'only the owner manages moderators'; end if;
  update room_members set role = case when p_on then 'moderator' else 'member' end where room_id=p_room and user_id=p_user;
end $$;

create or replace function send_room_message(p_room uuid, p_body text) returns void
language plpgsql security definer set search_path=public as $$
declare r rooms;
begin
  select * into r from rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if exists(select 1 from room_bans where room_id=p_room and user_id=auth.uid()) then raise exception 'banned'; end if;
  if not room_allows(p_room, auth.uid(), r.chat_permission) then raise exception 'chat is restricted in this room'; end if;
  insert into room_messages(room_id,user_id,body) values (p_room, auth.uid(), p_body);
end $$;

-- take_seat now honours mic_permission
create or replace function take_seat(p_room uuid, p_seat int) returns void
language plpgsql security definer set search_path=public as $$
declare r rooms;
begin
  select * into r from rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if not room_allows(p_room, auth.uid(), r.mic_permission) then raise exception 'mic is restricted in this room'; end if;
  if not exists(select 1 from room_members where room_id=p_room and user_id=auth.uid()) and r.owner_id<>auth.uid() then raise exception 'join the room first'; end if;
  insert into mic_seats(room_id,seat_no) values (p_room,p_seat) on conflict do nothing;
  update mic_seats set user_id=auth.uid() where room_id=p_room and seat_no=p_seat and user_id is null and not locked;
  if not found then raise exception 'seat unavailable'; end if;
end $$;

-- create_room: owner is always the caller; seats pre-created 1..10
create or replace function create_room(p_name text, p_country text, p_password text default null) returns uuid
language plpgsql security definer set search_path=public as $$
declare rid uuid;
begin
  insert into rooms(owner_id,name,country,is_private,password_hash)
   values (auth.uid(), p_name, p_country, coalesce(p_password,'')<>'', case when coalesce(p_password,'')<>'' then crypt(p_password, gen_salt('bf')) end)
   returning id into rid;
  insert into mic_seats(room_id,seat_no) select rid, g from generate_series(1,10) g;
  insert into room_members(room_id,user_id,role) values (rid, auth.uid(), 'member') on conflict do nothing;
  return rid;
end $$;
revoke insert on rooms from authenticated;

revoke all on function update_room_settings, set_room_password, set_moderator, send_room_message, create_room, room_allows from public;
grant execute on function update_room_settings, set_room_password, set_moderator, send_room_message, create_room to authenticated;

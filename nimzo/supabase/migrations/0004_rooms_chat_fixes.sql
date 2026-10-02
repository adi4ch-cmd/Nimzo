-- Room permissions, room chat, room follows, moderators, settings RPC, gift-event visibility, fixes.

alter table rooms add column if not exists perm_mic boolean not null default true;
alter table rooms add column if not exists perm_chat boolean not null default true;
alter table rooms add column if not exists perm_guest boolean not null default true;
alter table rooms add column if not exists perm_gift boolean not null default true;
alter table rooms add column if not exists perm_music boolean not null default true;
alter table rooms add column if not exists perm_game boolean not null default true;
alter table rooms add column if not exists perm_visitor boolean not null default true;
alter table rooms add column if not exists last_active timestamptz default now();
alter table room_members add column if not exists joined_at timestamptz default now();

create table room_messages (id uuid primary key default gen_random_uuid(), room_id uuid not null references rooms(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade, body text not null check (char_length(body) between 1 and 300), created_at timestamptz default now());
create index on room_messages (room_id, created_at desc);
create table room_follows (room_id uuid references rooms(id) on delete cascade, user_id uuid references profiles(id) on delete cascade, primary key(room_id,user_id));
alter table room_messages enable row level security;
alter table room_follows enable row level security;
create policy rm_read on room_messages for select to authenticated using (exists(select 1 from room_members m where m.room_id=room_messages.room_id and m.user_id=auth.uid()));
revoke insert, update, delete on room_messages from authenticated;
create policy rf_own on room_follows for select to authenticated using (user_id=auth.uid());
-- Room members may see gift events for that room (drives the gift animation).
create policy gift_events_room on gift_events for select to authenticated
  using (exists(select 1 from room_members m where m.room_id=gift_events.room_id and m.user_id=auth.uid()));

-- crypt() lives in the `extensions` schema on Supabase, so include it in search_path.
create or replace function join_room(p_room uuid, p_password text default null) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare r rooms;
begin
  select * into r from rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if exists(select 1 from room_bans where room_id=p_room and user_id=auth.uid()) then raise exception 'banned from room'; end if;
  if r.is_private and r.owner_id <> auth.uid() and (p_password is null or r.password_hash is distinct from crypt(p_password, r.password_hash)) then
    raise exception 'wrong password (password required)';
  end if;
  insert into room_members(room_id,user_id) values (p_room,auth.uid()) on conflict do nothing;
  update rooms set last_active=now() where id=p_room;
end $$;

create or replace function update_room_settings(p_room uuid, p_name text, p_theme text, p_private boolean, p_password text,
  p_mic boolean, p_chat boolean, p_guest boolean, p_gift boolean, p_music boolean, p_game boolean, p_visitor boolean) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then raise exception 'only the owner can change settings'; end if;
  if p_theme not in ('nimzo_white','sage','ocean','lavender','rose','midnight','premium_black','luxury') then raise exception 'unknown theme'; end if;
  update rooms set name=p_name, theme=p_theme, is_private=p_private,
    password_hash = case when p_private and p_password is not null and p_password<>'' then crypt(p_password, gen_salt('bf')) when not p_private then null else password_hash end,
    perm_mic=p_mic, perm_chat=p_chat, perm_guest=p_guest, perm_gift=p_gift, perm_music=p_music, perm_game=p_game, perm_visitor=p_visitor
  where id=p_room;
end $$;

create or replace function set_moderator(p_room uuid, p_user uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then raise exception 'only the owner can manage moderators'; end if;
  update room_members set role=case when p_on then 'moderator' else 'member' end where room_id=p_room and user_id=p_user;
end $$;

create or replace function room_member_list(p_room uuid) returns table(user_id uuid, display_name text, role text)
language sql stable security definer set search_path = public as $$
  select m.user_id, p.display_name, m.role from room_members m join profiles p on p.id=m.user_id
  where m.room_id=p_room and exists(select 1 from room_members me where me.room_id=p_room and me.user_id=auth.uid()) order by m.role, p.display_name $$;

create or replace function send_room_chat(p_room uuid, p_body text) returns void
language plpgsql security definer set search_path = public as $$
declare r rooms; is_staff boolean;
begin
  select * into r from rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if not exists(select 1 from room_members where room_id=p_room and user_id=auth.uid()) then raise exception 'join the room first'; end if;
  is_staff := can_moderate(p_room, auth.uid());
  if not r.perm_chat and not is_staff then raise exception 'chat is turned off in this room'; end if;
  insert into room_messages(room_id,user_id,body) values (p_room,auth.uid(),left(p_body,300));
end $$;

create or replace function follow_room(p_room uuid, p_on boolean) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_on then insert into room_follows values (p_room,auth.uid()) on conflict do nothing;
  else delete from room_follows where room_id=p_room and user_id=auth.uid(); end if;
end $$;

create or replace function my_rooms() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
   'recent', coalesce((select jsonb_agg(to_jsonb(r)) from (select rooms.* from room_members m join rooms on rooms.id=m.room_id where m.user_id=auth.uid() and rooms.status='open' order by m.joined_at desc limit 10) r), '[]'::jsonb),
   'followed', coalesce((select jsonb_agg(to_jsonb(r)) from (select rooms.* from room_follows f join rooms on rooms.id=f.room_id where f.user_id=auth.uid() and rooms.status='open' limit 20) r), '[]'::jsonb)) $$;

-- Enforce room permissions in the seat RPC (mic permission).
create or replace function take_seat(p_room uuid, p_seat int) returns void
language plpgsql security definer set search_path = public as $$
declare r rooms;
begin
  select * into r from rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if not exists(select 1 from room_members where room_id=p_room and user_id=auth.uid()) and r.owner_id<>auth.uid() then raise exception 'join the room first'; end if;
  if not r.perm_mic and not can_moderate(p_room, auth.uid()) then raise exception 'mic is turned off in this room'; end if;
  insert into mic_seats(room_id,seat_no) values (p_room,p_seat) on conflict do nothing;
  update mic_seats set user_id=auth.uid() where room_id=p_room and seat_no=p_seat and user_id is null and not locked;
  if not found then raise exception 'seat unavailable'; end if;
end $$;

-- Popular ordering: most members first. The client only displays this order.
create or replace view rooms_ranked as
  select r.*, (select count(*) from room_members m where m.room_id=r.id) as member_count from rooms r where r.status='open';

revoke all on function update_room_settings, set_moderator, room_member_list, send_room_chat, follow_room, my_rooms from public;
grant execute on function update_room_settings, set_moderator, room_member_list, send_room_chat, follow_room, my_rooms to authenticated;
insert into gifts(name,category,coin_price) values
 ('Rose','popular',100),('Heart','love',500),('Confetti','celebration',1000),('Crown','luxury',50000),('Star','new',300),('Comet','special',20000)
on conflict do nothing;

-- Gift permission enforced inside send_gift as well.
create or replace function send_gift(p_room uuid, p_receiver uuid, p_gift uuid, p_qty int, p_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_sender uuid := auth.uid(); v_owner uuid; v_allow boolean; v_price bigint; v_total bigint; v_diamonds bigint; v_owner_coins bigint;
        v_min_vip int; v_min_svip int; v_p profiles;
begin
  if v_sender is null then raise exception 'not authenticated'; end if;
  if p_qty < 1 or p_qty > 9999 then raise exception 'bad quantity'; end if;
  if v_sender = p_receiver then raise exception 'cannot gift yourself'; end if;
  if exists(select 1 from ledger where user_id=v_sender and kind='gift_sent' and idempotency_key=p_key) then return jsonb_build_object('status','replayed'); end if;
  select owner_id, perm_gift into v_owner, v_allow from rooms where id=p_room and status='open';
  if v_owner is null then raise exception 'room unavailable'; end if;
  if not v_allow then raise exception 'gifts are turned off in this room'; end if;
  if not exists(select 1 from room_members where room_id=p_room and user_id=p_receiver) then raise exception 'receiver is not in this room'; end if;
  select * into v_p from profiles where id=v_sender and status='active';
  if not found then raise exception 'account restricted'; end if;
  if exists(select 1 from blocks where blocker_id=p_receiver and blocked_id=v_sender) then raise exception 'blocked'; end if;
  select coin_price, min_vip, min_svip into v_price, v_min_vip, v_min_svip from gifts where id=p_gift and active;
  if v_price is null then raise exception 'gift unavailable'; end if;
  if v_p.vip_level < v_min_vip or v_p.svip_level < v_min_svip then raise exception 'tier required'; end if;
  v_total := v_price * p_qty; v_diamonds := (v_total * 45) / 100; v_owner_coins := (v_total * 5) / 100;
  perform 1 from wallets where user_id in (v_sender, p_receiver, v_owner) order by user_id for update;
  update wallets set coins = coins - v_total where user_id = v_sender and coins >= v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update wallets set diamonds = diamonds + v_diamonds where user_id = p_receiver;
  update wallets set coins = coins + v_owner_coins where user_id = v_owner;
  insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
   (v_sender,'gift_sent',-v_total,0,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty),p_key),
   (p_receiver,'gift_received',0,v_diamonds,jsonb_build_object('room',p_room,'from',v_sender),p_key),
   (v_owner,'room_reward',v_owner_coins,0,jsonb_build_object('room',p_room),p_key);
  insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values (p_room,v_sender,p_receiver,p_gift,p_qty,v_total);
  insert into notifications(user_id,category,title,body) values (p_receiver,'gifts','You received a gift', v_diamonds||' diamonds');
  return jsonb_build_object('status','ok','total',v_total,'diamonds',v_diamonds,'owner_coins',v_owner_coins);
end $$;
revoke all on function send_gift from public; grant execute on function send_gift to authenticated;

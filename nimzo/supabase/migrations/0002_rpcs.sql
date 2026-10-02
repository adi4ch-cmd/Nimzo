-- Permission-checked RPCs. Clients cannot write these tables directly.

create or replace function public.can_moderate(p_room uuid, p_uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from rooms where id=p_room and owner_id=p_uid)
      or exists(select 1 from room_members where room_id=p_room and user_id=p_uid and role='moderator')
      or exists(select 1 from admins where user_id=p_uid)
$$;

create or replace function public.join_room(p_room uuid, p_password text default null) returns void
language plpgsql security definer set search_path = public as $$
declare r rooms;
begin
  select * into r from rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if exists(select 1 from room_bans where room_id=p_room and user_id=auth.uid()) then raise exception 'banned from room'; end if;
  if r.is_private and r.owner_id <> auth.uid()
     and (p_password is null or r.password_hash is distinct from crypt(p_password, r.password_hash)) then
    raise exception 'wrong password';
  end if;
  insert into room_members(room_id,user_id) values (p_room,auth.uid()) on conflict do nothing;
end $$;

create table if not exists public.room_bans (
  room_id uuid references rooms(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  primary key (room_id,user_id)
);
alter table public.room_bans enable row level security;

create or replace function public.leave_room(p_room uuid) returns void
language sql security definer set search_path = public as $$
  update mic_seats set user_id=null where room_id=p_room and user_id=auth.uid();
  delete from room_members where room_id=p_room and user_id=auth.uid() and role='member';
$$;

create or replace function public.take_seat(p_room uuid, p_seat int) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from room_members where room_id=p_room and user_id=auth.uid())
     and not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then
    raise exception 'join the room first';
  end if;
  insert into mic_seats(room_id,seat_no) values (p_room,p_seat) on conflict do nothing;
  update mic_seats set user_id=auth.uid()
   where room_id=p_room and seat_no=p_seat and user_id is null and not locked;
  if not found then raise exception 'seat unavailable'; end if;
end $$;

create or replace function public.leave_seat(p_room uuid) returns void
language sql security definer set search_path = public as $$
  update mic_seats set user_id=null where room_id=p_room and user_id=auth.uid();
$$;

create or replace function public.mod_mute_seat(p_room uuid, p_seat int, p_muted boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not can_moderate(p_room, auth.uid()) then raise exception 'not allowed'; end if;
  update mic_seats set muted=p_muted where room_id=p_room and seat_no=p_seat;
end $$;

-- Kick: owner/mod/admin only; SVIP5+ targets are protected from normal staff (admins can still act).
create or replace function public.kick_member(p_room uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare tgt_svip int; is_adm boolean;
begin
  if not can_moderate(p_room, auth.uid()) then raise exception 'not allowed'; end if;
  select svip_level into tgt_svip from profiles where id=p_user;
  is_adm := exists(select 1 from admins where user_id=auth.uid());
  if tgt_svip >= 5 and not is_adm then raise exception 'target is protected'; end if;
  if exists(select 1 from rooms where id=p_room and owner_id=p_user) then raise exception 'cannot kick owner'; end if;
  update mic_seats set user_id=null where room_id=p_room and user_id=p_user;
  delete from room_members where room_id=p_room and user_id=p_user;
  insert into room_bans(room_id,user_id) values (p_room,p_user) on conflict do nothing;
end $$;

create or replace function public.accept_friend(p_requester uuid) returns void
language sql security definer set search_path = public as $$
  update friendships set status='accepted' where requester_id=p_requester and addressee_id=auth.uid();
$$;

-- Diamonds -> coins at 1:1, atomic + idempotent.
create or replace function public.exchange_diamonds(p_amount bigint, p_key text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_amount <= 0 then raise exception 'bad amount'; end if;
  if exists(select 1 from ledger where user_id=auth.uid() and kind='exchange' and idempotency_key=p_key) then return; end if;
  update wallets set diamonds=diamonds-p_amount, coins=coins+p_amount
   where user_id=auth.uid() and diamonds>=p_amount;
  if not found then raise exception 'insufficient diamonds'; end if;
  insert into ledger(user_id,kind,coin_delta,diamond_delta,idempotency_key)
   values (auth.uid(),'exchange',p_amount,-p_amount,p_key);
end $$;

-- Reseller top-up: verifies reseller + limit, writes ledger. No commission tiers.
create or replace function public.reseller_recharge(p_user uuid, p_coins bigint, p_key text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_coins <= 0 then raise exception 'bad amount'; end if;
  if not exists(select 1 from profiles where id=p_user and status='active') then raise exception 'user not found'; end if;
  if exists(select 1 from ledger where user_id=p_user and kind='reseller' and idempotency_key=p_key) then return; end if;
  update resellers set coin_limit=coin_limit-p_coins where user_id=auth.uid() and coin_limit>=p_coins;
  if not found then raise exception 'not a reseller or limit exceeded'; end if;
  update wallets set coins=coins+p_coins where user_id=p_user;
  insert into ledger(user_id,kind,coin_delta,ref,idempotency_key)
   values (p_user,'reseller',p_coins,jsonb_build_object('reseller',auth.uid()),p_key);
end $$;

-- Admin: ban/unban. Authorization is checked here, never in the app.
create or replace function public.admin_set_status(p_user uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  if p_status not in ('active','suspended','banned') then raise exception 'bad status'; end if;
  update profiles set status=p_status where id=p_user;
end $$;

revoke all on function join_room, leave_room, take_seat, leave_seat, mod_mute_seat, kick_member,
  accept_friend, exchange_diamonds, reseller_recharge, admin_set_status from public;
grant execute on function join_room, leave_room, take_seat, leave_seat, mod_mute_seat, kick_member,
  accept_friend, exchange_diamonds, reseller_recharge, admin_set_status to authenticated;

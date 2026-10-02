-- Nimzo core schema. Economy is server-authoritative; clients get read-only wallet access.
create extension if not exists pgcrypto;

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nimzo_id bigint generated always as identity (start with 100000) unique,
  username text unique check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  display_name text,
  bio text,
  avatar_path text,
  cover_path text,
  level int not null default 1,
  vip_level int not null default 0,
  vip_expires_at timestamptz,
  svip_level int not null default 0,
  svip_cycle_start timestamptz,
  status text not null default 'active' check (status in ('active','suspended','banned')),
  created_at timestamptz not null default now()
);
create table public.admins (user_id uuid primary key references auth.users(id));
create table public.resellers (
  user_id uuid primary key references auth.users(id),
  coin_limit bigint not null default 0 check (coin_limit >= 0)
);

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists(select 1 from admins where user_id = auth.uid()) $$;

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, display_name) values (new.id, split_part(new.email,'@',1));
  insert into wallets(user_id) values (new.id);
  return new;
end $$;

-- ---------- wallet + ledger ----------
create table public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coins bigint not null default 0 check (coins >= 0),
  diamonds bigint not null default 0 check (diamonds >= 0)
);
create table public.ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id),
  kind text not null,  -- gift_sent, gift_received, room_reward, recharge, reseller, vip_reward...
  coin_delta bigint not null default 0,
  diamond_delta bigint not null default 0,
  ref jsonb,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key, kind)
);
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- rooms ----------
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  room_no bigint generated always as identity (start with 10000) unique,
  owner_id uuid not null references profiles(id),
  name text not null check (char_length(name) between 1 and 40),
  country text,
  theme text not null default 'nimzo_white',
  is_private boolean not null default false,
  password_hash text,
  status text not null default 'open' check (status in ('open','closed','suspended')),
  created_at timestamptz not null default now()
);
create table public.room_members (
  room_id uuid references rooms(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member','moderator')),
  primary key (room_id, user_id)
);
create table public.mic_seats (
  room_id uuid references rooms(id) on delete cascade,
  seat_no int check (seat_no between 1 and 10),
  user_id uuid references profiles(id),
  muted boolean not null default false,
  locked boolean not null default false,
  primary key (room_id, seat_no)
);

-- ---------- gifts ----------
create table public.gifts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  coin_price bigint not null check (coin_price > 0),
  asset_path text,
  min_vip int not null default 0,
  min_svip int not null default 0,
  active boolean not null default true
);
create table public.gift_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id),
  sender_id uuid references profiles(id),
  receiver_id uuid references profiles(id),
  gift_id uuid references gifts(id),
  quantity int not null check (quantity > 0),
  total_coins bigint not null,
  created_at timestamptz not null default now()
);

-- ---------- social ----------
create table public.follows (
  follower_id uuid references profiles(id) on delete cascade,
  followee_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create table public.friendships (
  requester_id uuid references profiles(id) on delete cascade,
  addressee_id uuid references profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);
create table public.blocks (
  blocker_id uuid references profiles(id) on delete cascade,
  blocked_id uuid references profiles(id) on delete cascade,
  primary key (blocker_id, blocked_id)
);

-- ---------- ECONOMY: single entry point for gifts ----------
-- 100000 sent -> 45000 receiver diamonds + 5000 room-owner coins (integer math, floor).
create or replace function public.send_gift(
  p_room uuid, p_receiver uuid, p_gift uuid, p_qty int, p_key text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_sender uuid := auth.uid();
  v_owner uuid; v_price bigint; v_total bigint;
  v_diamonds bigint; v_owner_coins bigint;
  v_min_vip int; v_min_svip int; v_p profiles;
begin
  if v_sender is null then raise exception 'not authenticated'; end if;
  if p_qty < 1 or p_qty > 100000 then raise exception 'bad quantity'; end if;
  if v_sender = p_receiver then raise exception 'cannot gift yourself'; end if;

  -- idempotent replay
  if exists(select 1 from ledger where user_id=v_sender and kind='gift_sent' and idempotency_key=p_key) then
    return jsonb_build_object('status','replayed');
  end if;

  select owner_id into v_owner from rooms where id=p_room and status='open';
  if v_owner is null then raise exception 'room unavailable'; end if;
  select * into v_p from profiles where id=v_sender and status='active';
  if not found then raise exception 'account restricted'; end if;
  if exists(select 1 from blocks where (blocker_id=p_receiver and blocked_id=v_sender)) then
    raise exception 'blocked';
  end if;

  select coin_price, min_vip, min_svip into v_price, v_min_vip, v_min_svip
    from gifts where id=p_gift and active;
  if v_price is null then raise exception 'gift unavailable'; end if;
  if v_p.vip_level < v_min_vip or v_p.svip_level < v_min_svip then
    raise exception 'tier required';
  end if;

  v_total := v_price * p_qty;
  v_diamonds := (v_total * 45) / 100;
  v_owner_coins := (v_total * 5) / 100;

  -- lock wallets in a stable order to avoid deadlocks
  perform 1 from wallets
   where user_id in (v_sender, p_receiver, v_owner)
   order by user_id for update;

  update wallets set coins = coins - v_total where user_id = v_sender and coins >= v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update wallets set diamonds = diamonds + v_diamonds where user_id = p_receiver;
  update wallets set coins = coins + v_owner_coins where user_id = v_owner;

  insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
   (v_sender,'gift_sent',-v_total,0,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty),p_key),
   (p_receiver,'gift_received',0,v_diamonds,jsonb_build_object('room',p_room,'from',v_sender),p_key),
   (v_owner,'room_reward',v_owner_coins,0,jsonb_build_object('room',p_room),p_key);

  insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
   values (p_room,v_sender,p_receiver,p_gift,p_qty,v_total);

  return jsonb_build_object('status','ok','total',v_total,'diamonds',v_diamonds,'owner_coins',v_owner_coins);
end $$;
revoke all on function public.send_gift from public;
grant execute on function public.send_gift to authenticated;

-- ---------- RLS ----------
alter table profiles enable row level security;
alter table wallets enable row level security;
alter table ledger enable row level security;
alter table rooms enable row level security;
alter table room_members enable row level security;
alter table mic_seats enable row level security;
alter table gifts enable row level security;
alter table gift_events enable row level security;
alter table follows enable row level security;
alter table friendships enable row level security;
alter table blocks enable row level security;
alter table admins enable row level security;
alter table resellers enable row level security;

create policy profiles_read on profiles for select to authenticated using (true);
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- Column-level lock: users may edit only these. vip/svip/level/status stay server-only.
revoke update on profiles from authenticated;
grant update (username, display_name, bio, avatar_path, cover_path) on profiles to authenticated;

create policy wallet_own on wallets for select to authenticated using (user_id = auth.uid());
create policy ledger_own on ledger for select to authenticated using (user_id = auth.uid());
revoke insert, update, delete on wallets, ledger, gift_events from authenticated, anon;

create policy gifts_read on gifts for select to authenticated using (active);
create policy gift_events_read on gift_events for select to authenticated
  using (sender_id = auth.uid() or receiver_id = auth.uid());

create policy rooms_read on rooms for select to authenticated using (true);
create policy rooms_insert on rooms for insert to authenticated with check (owner_id = auth.uid());
create policy rooms_update on rooms for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
revoke update on rooms from authenticated;
grant update (name, country, theme, is_private) on rooms to authenticated;  -- owner_id/status immutable

create policy members_read on room_members for select to authenticated using (true);
create policy seats_read on mic_seats for select to authenticated using (true);
-- Joining, moderator role, and seat changes go through RPCs (add in 0002) that check permissions.
revoke insert, update, delete on room_members, mic_seats from authenticated;

create policy follows_read on follows for select to authenticated using (true);
create policy follows_write on follows for insert to authenticated with check (follower_id = auth.uid());
create policy follows_del on follows for delete to authenticated using (follower_id = auth.uid());

create policy fr_read on friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));
create policy fr_insert on friendships for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending');
create policy fr_delete on friendships for delete to authenticated
  using (auth.uid() in (requester_id, addressee_id));
-- accepting a request: RPC (0002), not a client update.

create policy blocks_own on blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy admins_none on admins for select to authenticated using (false);
create policy resellers_none on resellers for select to authenticated using (user_id = auth.uid());

-- ---------- economy test (run in SQL editor with two test users) ----------
-- Give sender 100000 coins via service role, gift priced 100000, qty 1:
--   expect receiver.diamonds = 45000, owner.coins += 5000, sender.coins -= 100000.
-- Security: as an authenticated user, each of these must FAIL:
--   update wallets set coins = 1e9;  update profiles set vip_level = 10;
--   update rooms set owner_id = auth.uid();  insert into admins values (auth.uid());

-- Nimzo locked profile, lifetime room gifting and Moment gifting.
-- Apply after the existing core/features/room migrations.

-- ---------- profile identity ----------
alter table public.profiles add column if not exists country_code text;
alter table public.profiles add column if not exists country_name text;
alter table public.profiles add column if not exists language text not null default 'English' check (language in ('English','Arabic'));
alter table public.profiles add column if not exists date_of_birth date;
alter table public.profiles add column if not exists gender text;
alter table public.profiles add column if not exists wealth_level int not null default 1 check (wealth_level >= 1);
alter table public.profiles add column if not exists charm_level int not null default 1 check (charm_level >= 1);
alter table public.profiles add column if not exists active_level int not null default 1 check (active_level >= 1);

-- Username/nickname is no longer part of the product UI. Keep legacy columns for migration safety,
-- but do not expose them through the Flutter profile editor.
revoke update (username, display_name) on public.profiles from authenticated;
grant update (bio, avatar_path, cover_path, country_code, country_name, language, date_of_birth, gender) on public.profiles to authenticated;

-- ---------- admin/activity tags ----------
create table if not exists public.profile_tags (
  user_id uuid not null references public.profiles(id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 40),
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, tag)
);
alter table public.profile_tags enable row level security;
do $$ begin if not exists (select 1 from pg_policies where schemaname='public' and tablename='profile_tags' and policyname='profile_tags_read') then create policy profile_tags_read on public.profile_tags for select to authenticated using (true); end if; end $$;
revoke insert, update, delete on public.profile_tags from authenticated;

-- ---------- CP / Couple ----------
create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  title text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (user_a <> user_b)
);
create unique index if not exists couples_active_user_a on public.couples(user_a) where active;
create unique index if not exists couples_active_user_b on public.couples(user_b) where active;
alter table public.couples enable row level security;
do $$ begin if not exists (select 1 from pg_policies where schemaname='public' and tablename='couples' and policyname='couples_read') then create policy couples_read on public.couples for select to authenticated using (active); end if; end $$;
revoke insert, update, delete on public.couples from authenticated;

-- ---------- Model system foundation ----------
create table if not exists public.models (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists models_user_active on public.models(user_id, active, created_at desc);
alter table public.models enable row level security;
do $$ begin if not exists (select 1 from pg_policies where schemaname='public' and tablename='models' and policyname='models_read') then create policy models_read on public.models for select to authenticated using (active); end if; end $$;
revoke insert, update, delete on public.models from authenticated;

-- ---------- Room lifetime gifting ----------
alter table public.rooms add column if not exists lifetime_gift_coins bigint not null default 0 check (lifetime_gift_coins >= 0);

-- Increment lifetime room gifting inside the same transaction as the gift.
create or replace function public.send_gift(p_room uuid, p_receiver uuid, p_gift uuid, p_qty int, p_key text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_sender uuid := auth.uid(); v_owner uuid; v_allow boolean := true;
  v_price bigint; v_total bigint; v_diamonds bigint; v_owner_coins bigint;
  v_min_vip int; v_min_svip int; v_p profiles;
begin
  if v_sender is null then raise exception 'not authenticated'; end if;
  if p_qty < 1 or p_qty > 9999 then raise exception 'bad quantity'; end if;
  if v_sender = p_receiver then raise exception 'cannot gift yourself'; end if;
  if exists(select 1 from ledger where user_id=v_sender and kind='gift_sent' and idempotency_key=p_key) then
    return jsonb_build_object('status','replayed');
  end if;
  select owner_id, coalesce(perm_gift,true) into v_owner, v_allow from rooms where id=p_room and status='open';
  if v_owner is null then raise exception 'room unavailable'; end if;
  if not v_allow then raise exception 'gifts are turned off in this room'; end if;
  if not exists(select 1 from room_members where room_id=p_room and user_id=p_receiver) then raise exception 'receiver is not in this room'; end if;
  select * into v_p from profiles where id=v_sender and status='active';
  if not found then raise exception 'account restricted'; end if;
  if exists(select 1 from blocks where blocker_id=p_receiver and blocked_id=v_sender) then raise exception 'blocked'; end if;
  select coin_price,min_vip,min_svip into v_price,v_min_vip,v_min_svip from gifts where id=p_gift and active;
  if v_price is null then raise exception 'gift unavailable'; end if;
  if v_p.vip_level < v_min_vip or v_p.svip_level < v_min_svip then raise exception 'tier required'; end if;
  v_total := v_price*p_qty; v_diamonds := (v_total*45)/100; v_owner_coins := (v_total*5)/100;
  perform 1 from wallets where user_id in (v_sender,p_receiver,v_owner) order by user_id for update;
  update wallets set coins=coins-v_total where user_id=v_sender and coins>=v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update wallets set diamonds=diamonds+v_diamonds where user_id=p_receiver;
  update wallets set coins=coins+v_owner_coins where user_id=v_owner;
  update rooms set lifetime_gift_coins=lifetime_gift_coins+v_total where id=p_room;
  insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
    (v_sender,'gift_sent',-v_total,0,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty),p_key),
    (p_receiver,'gift_received',0,v_diamonds,jsonb_build_object('room',p_room,'from',v_sender),p_key),
    (v_owner,'room_reward',v_owner_coins,0,jsonb_build_object('room',p_room),p_key);
  insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(p_room,v_sender,p_receiver,p_gift,p_qty,v_total);
  return jsonb_build_object('status','ok','total',v_total,'diamonds',v_diamonds,'owner_coins',v_owner_coins,'room_lifetime_gifts',v_total);
end $$;
revoke all on function public.send_gift(uuid,uuid,uuid,int,text) from public;
grant execute on function public.send_gift(uuid,uuid,uuid,int,text) to authenticated;

-- ---------- Moment gifts ----------
alter table public.moments add column if not exists lifetime_gift_coins bigint not null default 0 check (lifetime_gift_coins >= 0);
create table if not exists public.moment_gift_events (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  gift_id uuid not null references public.gifts(id),
  quantity int not null check (quantity > 0),
  total_coins bigint not null check (total_coins > 0),
  created_at timestamptz not null default now()
);
alter table public.moment_gift_events enable row level security;
do $$ begin if not exists (select 1 from pg_policies where schemaname='public' and tablename='moment_gift_events' and policyname='moment_gift_events_read') then create policy moment_gift_events_read on public.moment_gift_events for select to authenticated using (sender_id=auth.uid() or receiver_id=auth.uid()); end if; end $$;
revoke insert, update, delete on public.moment_gift_events from authenticated;

create or replace function public.send_moment_gift(p_moment uuid, p_receiver uuid, p_gift uuid, p_qty int, p_key text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_sender uuid := auth.uid(); v_author uuid; v_price bigint; v_total bigint; v_diamonds bigint;
  v_min_vip int; v_min_svip int; v_p profiles;
begin
  if v_sender is null then raise exception 'not authenticated'; end if;
  if p_qty < 1 or p_qty > 9999 then raise exception 'bad quantity'; end if;
  if v_sender=p_receiver then raise exception 'cannot gift yourself'; end if;
  if exists(select 1 from ledger where user_id=v_sender and kind='moment_gift_sent' and idempotency_key=p_key) then
    return jsonb_build_object('status','replayed');
  end if;
  select author_id into v_author from moments where id=p_moment;
  if v_author is null then raise exception 'moment unavailable'; end if;
  if v_author<>p_receiver then raise exception 'receiver is not the moment owner'; end if;
  if exists(select 1 from blocks where (blocker_id=p_receiver and blocked_id=v_sender) or (blocker_id=v_sender and blocked_id=p_receiver)) then raise exception 'blocked'; end if;
  select * into v_p from profiles where id=v_sender and status='active';
  if not found then raise exception 'account restricted'; end if;
  select coin_price,min_vip,min_svip into v_price,v_min_vip,v_min_svip from gifts where id=p_gift and active;
  if v_price is null then raise exception 'gift unavailable'; end if;
  if v_p.vip_level<v_min_vip or v_p.svip_level<v_min_svip then raise exception 'tier required'; end if;
  v_total:=v_price*p_qty; v_diamonds:=(v_total*45)/100;
  perform 1 from wallets where user_id in (v_sender,p_receiver) order by user_id for update;
  update wallets set coins=coins-v_total where user_id=v_sender and coins>=v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update wallets set diamonds=diamonds+v_diamonds where user_id=p_receiver;
  update moments set lifetime_gift_coins=lifetime_gift_coins+v_total where id=p_moment;
  insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
    (v_sender,'moment_gift_sent',-v_total,0,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty),p_key),
    (p_receiver,'moment_gift_received',0,v_diamonds,jsonb_build_object('moment',p_moment,'from',v_sender),p_key);
  insert into moment_gift_events(moment_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(p_moment,v_sender,p_receiver,p_gift,p_qty,v_total);
  insert into notifications(user_id,category,title,body) values(p_receiver,'gifts','You received a Moment gift',v_diamonds||' diamonds');
  return jsonb_build_object('status','ok','total',v_total,'diamonds',v_diamonds);
end $$;
revoke all on function public.send_moment_gift(uuid,uuid,uuid,int,text) from public;
grant execute on function public.send_moment_gift(uuid,uuid,uuid,int,text) to authenticated;

create index if not exists moment_gift_events_moment_created on public.moment_gift_events(moment_id, created_at desc);

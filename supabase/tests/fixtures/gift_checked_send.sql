-- DISPOSABLE DATABASE ONLY. Structural fixture, not production schema/migration.
create schema auth;
create schema nimzo_private;
create schema nimzo_internal;
create schema extensions;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.profiles(id uuid primary key,status text not null default 'active',vip_level integer not null default 0,vip_expires_at timestamptz);
create table public.wallets(user_id uuid primary key,coins bigint not null default 0,diamonds bigint not null default 0);
create table public.gifts(id uuid primary key,coin_price bigint not null,active boolean not null default false,requires_approved_media boolean not null default false);
create table public.rooms(id uuid primary key,owner_id uuid,status text not null default 'open',perm_gift boolean not null default true,gift_permission text default 'all');
create table public.room_members(room_id uuid,user_id uuid,primary key(room_id,user_id));
create table public.room_bans(room_id uuid,user_id uuid,primary key(room_id,user_id));
create table public.blocks(blocker_id uuid,blocked_id uuid);
create table public.moments(id uuid primary key,author_id uuid,lifetime_gift_coins bigint not null default 0);
create table public.ledger(id bigint generated always as identity primary key,user_id uuid not null,kind text not null,coin_delta bigint not null default 0,diamond_delta bigint not null default 0,ref jsonb not null default '{}',idempotency_key text not null,unique(user_id,idempotency_key,kind));
create table public.gift_events(id bigint generated always as identity primary key,room_id uuid,sender_id uuid,receiver_id uuid,gift_id uuid,quantity integer,total_coins bigint);
create table public.gift_animation_media(gift_id uuid primary key,approved boolean not null default false,video_url text,media_kind text);
create table public.nimzo_cosmetic_catalog(id text primary key,active boolean,coin_price bigint);
create table public.nimzo_cosmetic_media(item_id text primary key,approved boolean not null default false,asset_url text,media_kind text);
create function public.room_allows(p_room uuid,p_user uuid,p_permission text) returns boolean language sql as $$
 select p_permission='all'
$$;
-- Exercise the wrapper through real authenticated privileges, not table grants.
alter table public.ledger enable row level security;
alter table public.wallets enable row level security;
revoke all on public.ledger,public.wallets from public,anon,authenticated;

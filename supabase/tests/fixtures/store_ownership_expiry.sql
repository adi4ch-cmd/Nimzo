-- DISPOSABLE DATABASE ONLY. Minimal structures needed by the actual migrations.
create schema auth;
create schema nimzo_internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.profiles(id uuid primary key,status text not null default 'active');
create table public.wallets(user_id uuid primary key,coins bigint not null default 0);
create table public.ledger(id bigint generated always as identity primary key,
 user_id uuid not null,kind text not null,coin_delta bigint not null default 0,
 diamond_delta bigint not null default 0,ref jsonb not null default '{}',
 idempotency_key text not null,unique(user_id,kind,idempotency_key));
create table public.gifts(id uuid primary key,coin_price bigint,active boolean,
 requires_approved_media boolean not null default false);
create table public.gift_animation_media(gift_id uuid primary key,video_url text,
 media_kind text,approved boolean not null default false);
create table public.nimzo_cosmetic_media(item_id text primary key,asset_url text,
 media_kind text,approved boolean not null default false);
alter table public.wallets enable row level security;
alter table public.ledger enable row level security;
revoke all on public.wallets,public.ledger from public,anon,authenticated;
insert into auth.users values('00000000-0000-0000-0000-000000000001');
insert into public.profiles(id) select id from auth.users;
insert into public.wallets(user_id,coins) select id,1000 from auth.users;

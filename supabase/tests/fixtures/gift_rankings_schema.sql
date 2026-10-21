-- Minimal contract fixture for an EMPTY disposable PostgreSQL instance only.
-- Load this, then 20261021001027_authoritative_gift_rankings_all_periods.sql,
-- then ../gift_rankings.sql with psql -v ON_ERROR_STOP=1. No production data.
create role anon;
create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to authenticated;
create table public.profiles(id uuid primary key, display_name text, status text);
create table public.ledger(
  user_id uuid, kind text, coin_delta bigint, diamond_delta bigint,
  created_at timestamptz
);
create table public.gift_events(room_id uuid, total_coins bigint, created_at timestamptz);
create table public.rooms(id uuid primary key, name text);

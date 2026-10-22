-- Structural fixture for a NEW disposable database only.
create schema auth;
create schema nimzo_private;
create schema nimzo_internal;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create table public.rooms(id uuid primary key);
create table public.room_members(room_id uuid,user_id uuid,primary key(room_id,user_id));
create table public.gift_events(id uuid primary key default gen_random_uuid(),room_id uuid,total_coins bigint,created_at timestamptz not null default statement_timestamp());
create table public.nimzo_content_revisions(channel text primary key,revision bigint not null,updated_at timestamptz not null);
grant usage on schema public,auth,nimzo_private to authenticated;
create publication supabase_realtime;

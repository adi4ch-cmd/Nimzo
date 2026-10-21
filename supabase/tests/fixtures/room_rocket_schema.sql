create schema auth; create schema nimzo_private;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.rooms(id uuid primary key);
create table public.room_members(room_id uuid,user_id uuid,primary key(room_id,user_id));
create table public.gift_events(id uuid primary key default gen_random_uuid(),room_id uuid,total_coins bigint,created_at timestamptz default statement_timestamp());
grant usage on schema public,auth,nimzo_private to authenticated;

-- Focused disposable PostgreSQL schema, NOT a production migration.
-- Omits unrelated business triggers/FKs; validates milestone SQL and auth scope.
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
do $$ begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
end $$;
create table public.profiles(id uuid primary key,status text default 'active');
create table public.gift_events(id uuid primary key,sender_id uuid,receiver_id uuid,total_coins bigint,created_at timestamptz);
create table public.ledger(id bigint generated always as identity primary key,user_id uuid,kind text,diamond_delta bigint,ref jsonb,created_at timestamptz);
create table public.game_rounds(id uuid primary key,status text,settled_at timestamptz);
create table public.game_bets(id uuid primary key,round_id uuid,user_id uuid,status text,settled_at timestamptz);
create table public.rooms(id uuid primary key,owner_id uuid,created_at timestamptz);
insert into public.profiles(id) values('00000000-0000-4000-8000-000000001601'),('00000000-0000-4000-8000-000000001602');
grant usage on schema public,auth to authenticated;

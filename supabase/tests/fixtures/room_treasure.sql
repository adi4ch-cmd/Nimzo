-- Minimal disposable schema matching the inspected production column contracts.
create schema auth;
create schema cron;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated,anon,service_role;
create table profiles(id uuid primary key,status text default 'active',display_name text);
create table wallets(user_id uuid primary key references profiles,coins bigint not null check(coins>=0),diamonds bigint default 0);
create table ledger(id bigint generated always as identity primary key,user_id uuid,kind text,coin_delta bigint,diamond_delta bigint,ref jsonb,idempotency_key text,unique(user_id,idempotency_key,kind));
create table rooms(id uuid primary key,status text default 'open',is_private bool default false,perm_gift bool default true,gift_permission text default 'members');
create table room_members(room_id uuid references rooms,user_id uuid references profiles,primary key(room_id,user_id));
create table room_bans(room_id uuid,user_id uuid);
create table mic_seats(room_id uuid,user_id uuid,locked bool default false);
create table follows(follower_id uuid,followee_id uuid,primary key(follower_id,followee_id));
create function public.room_allows(uuid,uuid,text) returns bool language sql as $$select $3 in ('members','everyone')$$;
create table cron.job(jobname text primary key,schedule text,command text);
create function cron.schedule(text,text,text) returns bigint language plpgsql as $$begin
 insert into cron.job values($1,$2,$3) on conflict(jobname) do update set schedule=excluded.schedule,command=excluded.command;return 1;end$$;

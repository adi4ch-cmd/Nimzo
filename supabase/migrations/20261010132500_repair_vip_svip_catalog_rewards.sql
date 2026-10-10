-- NIMZO VIP/SVIP contract repair. Existing users, balances, historical
-- VIP/SVIP entitlements and ledger rows are NEVER reset by this migration.
-- Haza media is NOT copied into Nimzo. Only approved NIMZO values apply.
begin;

insert into public.svip_thresholds(level,usd_cents) values
 (1,5000),(2,20000),(3,50000),(4,100000),(5,300000),
 (6,1000000),(7,3000000),(8,7500000),(9,20000000),(10,50000000)
on conflict(level) do update set usd_cents=excluded.usd_cents;

insert into public.svip_friday_rewards(level,coins) values
 (1,2000000),(2,5000000),(3,10000000),(4,20000000),
 (5,40000000),(6,80000000),(7,150000000),(8,250000000),
 (9,450000000),(10,800000000)
on conflict(level) do update set coins=excluded.coins;

-- All exposed catalogs are immutable to public clients.
alter table public.svip_thresholds enable row level security;
alter table public.svip_friday_rewards enable row level security;
alter table public.vip_daily_rewards enable row level security;
alter table public.normal_vip_catalog enable row level security;
revoke all on public.svip_thresholds,public.svip_friday_rewards,
 public.vip_daily_rewards,public.normal_vip_catalog
 from public,anon,authenticated;
grant select on public.svip_thresholds,public.svip_friday_rewards,
 public.vip_daily_rewards,public.normal_vip_catalog to authenticated;

-- Keep the existing authenticated SELECT RLS policies in place.
-- The renamed Sunday cycle retains the historical RPC/table identifiers so
-- old clients do not fail with a missing function/table error.
create or replace function public.claim_vip_daily()
returns void language plpgsql security definer set search_path = ''
as $fn$
declare
 v_user uuid := auth.uid();
 v_date date := (pg_catalog.statement_timestamp() at time zone 'Asia/Riyadh')::date;
 v_profile public.profiles%rowtype;
 v_reward bigint;
begin
 if v_user is null then raise exception 'Sign in required'; end if;
 select * into v_profile from public.profiles
 where id=v_user and status='active' for update;
 if not found then raise exception 'Account unavailable'; end if;
 if v_profile.vip_level not between 1 and 10
    or v_profile.vip_expires_at is null
    or v_profile.vip_expires_at<=pg_catalog.statement_timestamp()
 then raise exception 'No active VIP'; end if;
 if v_profile.vip_last_claim=v_date then raise exception 'VIP reward already claimed today'; end if;
 select coins into v_reward from public.vip_daily_rewards
 where level=v_profile.vip_level;
 if v_reward is null or v_reward<=0 then raise exception 'VIP reward catalog unavailable'; end if;
 update public.wallets set coins=coins+v_reward where user_id=v_user;
 if not found then raise exception 'VIP wallet unavailable'; end if;
 update public.profiles set vip_last_claim=v_date where id=v_user;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,idempotency_key,ref)
 values(v_user,'vip_daily',v_reward,0,'vip-'||v_date,
 pg_catalog.jsonb_build_object('level',v_profile.vip_level,'claim_day',v_date,'time_zone','Asia/Riyadh'));
end;
$fn$;

-- Each SVIP week starts on Sunday at 21:00 Saudi local time. Claim once per
-- weekly window; users may claim during the following seven days.
create or replace function public.claim_svip_friday()
returns void language plpgsql security definer set search_path = ''
as $fn$
declare
 v_user uuid := auth.uid();
 v_local timestamp := pg_catalog.statement_timestamp() at time zone 'Asia/Riyadh';
 v_sunday_start timestamp;
 v_week_date date;
 v_profile public.profiles%rowtype;
 v_reward bigint;
begin
 if v_user is null then raise exception 'Sign in required'; end if;
 v_sunday_start := pg_catalog.date_trunc('week',v_local) + interval '6 days 21 hours';
 if v_local < v_sunday_start then v_sunday_start := v_sunday_start - interval '7 days'; end if;
 v_week_date:=v_sunday_start::date;
 select * into v_profile from public.profiles
 where id=v_user and status='active' for update;
 if not found then raise exception 'Account unavailable'; end if;
 if v_profile.svip_level not between 1 and 10
    or v_profile.svip_cycle_start is null
    or v_profile.svip_cycle_start + interval '90 days' <= pg_catalog.statement_timestamp()
 then raise exception 'No active SVIP'; end if;
 if v_profile.svip_last_claim = v_week_date then
    raise exception 'SVIP weekly reward already claimed';
 end if;
 -- A new/renewed cycle cannot claim an older weekly period that began
 -- before the member qualified for SVIP.
 if v_profile.svip_cycle_start >
    (v_sunday_start at time zone 'Asia/Riyadh')
 then raise exception 'SVIP weekly reward unlocks Sunday 21:00 Saudi time'; end if;
 select coins into v_reward from public.svip_friday_rewards
 where level=v_profile.svip_level;
 if v_reward is null or v_reward<=0 then raise exception 'SVIP reward catalog unavailable'; end if;
 update public.wallets set coins=coins+v_reward where user_id=v_user;
 if not found then raise exception 'SVIP wallet unavailable'; end if;
 update public.profiles set svip_last_claim=v_week_date where id=v_user;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,idempotency_key,ref)
 values(v_user,'svip_friday',v_reward,0,'svip-'||v_week_date,
 pg_catalog.jsonb_build_object('level',v_profile.svip_level,
 'weekly_sunday',v_week_date,'schedule','Sunday 21:00 Asia/Riyadh'));
end;
$fn$;

create or replace function public.vip_status()
returns jsonb language sql stable security definer set search_path = ''
as $fn$
 with clock as (
   select pg_catalog.statement_timestamp() as now_utc,
   pg_catalog.statement_timestamp() at time zone 'Asia/Riyadh' as local_time
 ), period as (
   select now_utc,local_time,
     (local_time::date) as local_day,
     case when local_time <
          pg_catalog.date_trunc('week',local_time) + interval '6 days 21 hours'
       then (pg_catalog.date_trunc('week',local_time) - interval '1 day')::date
       else (pg_catalog.date_trunc('week',local_time) + interval '6 days')::date
     end as weekly_sunday
   from clock
 )
 select pg_catalog.jsonb_build_object(
   'vip_level',case when p.vip_expires_at > c.now_utc and p.status='active'
      then p.vip_level else 0 end,
   'vip_expires_at',p.vip_expires_at,
   'vip_daily_claimed_today',p.vip_last_claim = c.local_day,
   'svip_level',case when p.svip_cycle_start is not null
      and p.svip_cycle_start + interval '90 days' > c.now_utc
      and p.status='active' then p.svip_level else 0 end,
   'svip_cycle_active',p.svip_cycle_start is not null
      and p.svip_cycle_start + interval '90 days' > c.now_utc
      and p.status='active',
   'svip_cycle_cents',case when p.svip_cycle_start is not null
      and p.svip_cycle_start + interval '90 days' <= c.now_utc
      then 0 else p.svip_cycle_cents end,
   'svip_weekly_claimed',p.svip_last_claim = c.weekly_sunday,
   'svip_current_week',c.weekly_sunday,
   'reward_timezone','Asia/Riyadh'
 ) from public.profiles p cross join period c
 where p.id=auth.uid()
$fn$;

revoke all on function public.claim_vip_daily(),
 public.claim_svip_friday(),public.vip_status() from public,anon,authenticated;
grant execute on function public.claim_vip_daily(),
 public.claim_svip_friday(),public.vip_status() to authenticated;
commit;
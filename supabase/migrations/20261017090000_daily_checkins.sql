-- NIMZO: UTC daily check-in with atomic, server-authoritative coin settlement.
-- Safe defaults: disabled until an operator explicitly configures
-- public.economy_settings(setting_key='daily_checkin_reward_coins',
-- numeric_value > 0, active=true). Never invent a reward amount in the app.
create table if not exists public.daily_checkins (
  user_id uuid not null references auth.users(id) on delete cascade,
  day_utc date not null,
  coins_awarded bigint not null check (coins_awarded > 0),
  created_at timestamptz not null default now(),
  primary key (user_id, day_utc)
);

alter table public.daily_checkins enable row level security;
revoke all on public.daily_checkins from anon, authenticated;
grant select on public.daily_checkins to authenticated;

drop policy if exists daily_checkins_read_own on public.daily_checkins;
create policy daily_checkins_read_own
  on public.daily_checkins for select to authenticated
  using (user_id = auth.uid());

create or replace function public.claim_daily_checkin()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_today date := (now() at time zone 'UTC')::date;
  v_reward bigint;
  v_previous date;
  v_streak int := 1;
  v_existing bigint;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('daily_checkin:' || v_user::text, 0));

  select coins_awarded into v_existing
  from public.daily_checkins
  where user_id = v_user and day_utc = v_today;

  if found then
    return jsonb_build_object(
      'status', 'already_claimed',
      'day_utc', v_today,
      'coins', v_existing);
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_user and status = 'active'
  ) then
    raise exception 'An active NIMZO account is required';
  end if;

  select numeric_value::bigint into v_reward
  from public.economy_settings
  where setting_key = 'daily_checkin_reward_coins'
    and active = true
    and numeric_value = trunc(numeric_value);

  if v_reward is null or v_reward < 1 or v_reward > 100000 then
    raise exception 'Daily reward is not configured'
      using errcode = 'P0001';
  end if;

  select day_utc into v_previous
  from public.daily_checkins
  where user_id = v_user and day_utc < v_today
  order by day_utc desc limit 1;

  if v_previous = v_today - 1 then
    with recursive previous_days(day, streak) as (
      select v_today - 1, 1
      union all
      select p.day - 1, p.streak + 1
      from previous_days p
      where p.streak < 365
        and exists (
          select 1 from public.daily_checkins d
          where d.user_id = v_user and d.day_utc = p.day - 1
        )
    )
    select 1 + coalesce(max(streak), 0)
      into v_streak from previous_days;
  end if;

  -- No account or ledger updates occur if no wallet exists.
  perform 1 from public.wallets
    where user_id = v_user for update;
  if not found then
    raise exception 'Wallet is unavailable';
  end if;

  insert into public.daily_checkins(user_id,day_utc,coins_awarded)
  values (v_user,v_today,v_reward);
  update public.wallets
  set coins = coins + v_reward where user_id = v_user;
  insert into public.ledger(
    user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  values (
    v_user,'daily_checkin',v_reward,0,
    jsonb_build_object('day_utc',v_today,'streak',v_streak),
    'daily_checkin:' || v_today::text
  );

  return jsonb_build_object(
    'status','claimed','coins',v_reward,
    'day_utc',v_today,'streak',v_streak);
end;
$$;

revoke all on function public.claim_daily_checkin() from public, anon;
grant execute on function public.claim_daily_checkin() to authenticated;

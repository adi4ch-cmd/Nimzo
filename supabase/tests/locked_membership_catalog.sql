-- Run against a staging database AFTER applying
-- 20261007_locked_svip_catalog.sql. Read-only assertions: no account,
-- wallet, ledger or membership changes.
do $$
declare
  expected_thresholds bigint[] := array[
    5000, 20000, 50000, 100000, 300000,
    1000000, 3000000, 7500000, 20000000, 50000000
  ];
  expected_rewards bigint[] := array[
    2000000, 5000000, 10000000, 20000000, 40000000,
    80000000, 150000000, 250000000, 450000000, 800000000
  ];
  actual_thresholds bigint[];
  actual_rewards bigint[];
  actual_rate numeric;
begin
  select array_agg(usd_cents order by level)
    into actual_thresholds from public.svip_thresholds
    where level between 1 and 10;
  if actual_thresholds is distinct from expected_thresholds then
    raise exception 'SVIP thresholds do not match locked catalog';
  end if;

  select array_agg(coins order by level)
    into actual_rewards from public.svip_friday_rewards
    where level between 1 and 10;
  if actual_rewards is distinct from expected_rewards then
    raise exception 'SVIP weekly coin amounts do not match locked catalog';
  end if;

  select numeric_value into actual_rate from public.economy_settings
    where setting_key = 'coins_per_usd' and active = true;
  if actual_rate is distinct from 500000::numeric then
    raise exception 'Coin exchange rate must remain 500000 per USD';
  end if;
end $$;

-- IMPORTANT: These checks validate catalog amounts only. They do not prove
-- Sunday 21:00 Asia/Riyadh scheduling, idempotency or 90-day eligibility.

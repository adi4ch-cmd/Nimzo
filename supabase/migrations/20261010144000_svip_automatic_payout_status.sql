-- Expose accurate auto-payout and fallback eligibility to Flutter clients.
-- No balances, user rows, old claims, or membership prices are changed.
CREATE OR REPLACE FUNCTION public.vip_status()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $fn$
  WITH clock AS (
    SELECT pg_catalog.statement_timestamp() AS now_utc,
      pg_catalog.statement_timestamp() AT TIME ZONE 'Asia/Riyadh' AS local_time
  ), periods AS (
    SELECT now_utc,local_time, local_time::date AS local_day,
      pg_catalog.date_trunc('week',local_time)
        + interval '6 days 21 hours' AS this_sunday_start
    FROM clock
  ), period AS (
    SELECT now_utc,local_time,local_day,this_sunday_start,
      CASE WHEN local_time < this_sunday_start
        THEN this_sunday_start-interval '7 days'
        ELSE this_sunday_start
      END AS active_week_start,
      CASE WHEN local_time < this_sunday_start
        THEN this_sunday_start ELSE this_sunday_start+interval '7 days'
      END AT TIME ZONE 'Asia/Riyadh' AS next_auto_at
    FROM periods
  )
  SELECT pg_catalog.jsonb_build_object(
    'vip_level', CASE WHEN p.vip_expires_at > c.now_utc
      AND p.status='active' THEN p.vip_level ELSE 0 END,
    'vip_expires_at',p.vip_expires_at,
    'vip_daily_claimed_today', p.vip_last_claim=c.local_day,
    'svip_level',CASE WHEN p.status='active'
      AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days' > c.now_utc
      THEN p.svip_level ELSE 0 END,
    'svip_cycle_active', p.status='active'
      AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days' > c.now_utc,
    'svip_cycle_cents',CASE WHEN p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days' <= c.now_utc
      THEN 0 ELSE p.svip_cycle_cents END,
    'svip_weekly_claimed', p.svip_last_claim=c.active_week_start::date,
    'svip_current_week', c.active_week_start::date,
    'svip_auto_enabled',true,
    'svip_next_payout_at',c.next_auto_at,
    'svip_weekly_claimable', p.status='active'
      AND p.svip_level BETWEEN 1 AND 10
      AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start <=
        (c.active_week_start AT TIME ZONE 'Asia/Riyadh')
      AND p.svip_cycle_start+interval '90 days'>c.now_utc
      AND p.svip_last_claim IS DISTINCT FROM c.active_week_start::date
      AND c.local_time >= c.active_week_start+interval '1 hour',
    'reward_timezone','Asia/Riyadh'
  )
  FROM public.profiles p CROSS JOIN period c
  WHERE p.id=auth.uid()
$fn$;
REVOKE ALL ON FUNCTION public.vip_status() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.vip_status() TO authenticated;
-- NIMZO SVIP: automatic Sunday 21:00 Asia/Riyadh payout (UTC 18:00).
-- User IDs, current membership, wallet balances and historical ledgers preserved.
-- The former 'svip_friday' ledger kind and 'claim_svip_friday' RPC remain
-- compatible with older clients. Both manual and automatic payouts share
-- one UNIQUE (user_id, idempotency_key, kind) ledger identity.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

CREATE TABLE IF NOT EXISTS nimzo_private.svip_sunday_payout_runs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 started_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
 week_sunday date NOT NULL,
 credited_count integer NOT NULL DEFAULT 0,
 already_paid_count integer NOT NULL DEFAULT 0,
 failed_count integer NOT NULL DEFAULT 0,
 payout_coins bigint NOT NULL DEFAULT 0,
 status text NOT NULL CHECK (status IN ('succeeded', 'partial_failure')),
 CHECK (credited_count>=0 AND already_paid_count>=0 AND failed_count>=0
    AND payout_coins>=0)
);
ALTER TABLE nimzo_private.svip_sunday_payout_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON nimzo_private.svip_sunday_payout_runs FROM PUBLIC,anon,authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA nimzo_private FROM anon,authenticated;

CREATE OR REPLACE FUNCTION nimzo_private.pay_svip_sunday_rewards()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path=''
AS $reward$
DECLARE
 v_now timestamptz := pg_catalog.statement_timestamp();
 v_local timestamp := v_now AT TIME ZONE 'Asia/Riyadh';
 v_this_sunday timestamp;
 v_sunday_utc timestamptz;
 v_week_date date;
 v_user record;
 v_amount bigint;
 v_ledger_id bigint;
 v_wallet_id uuid;
 v_count integer := 0;
 v_already integer := 0;
 v_failed integer := 0;
 v_total bigint := 0;
BEGIN
 -- Retry slots are 21:00, 21:15, 21:30 and 21:45 Saudi time.
 -- Anything outside this window, including an accidentally invoked manual
 -- RPC, is a NO-OP. UTC never changes its offset for Asia/Riyadh.
 IF extract(isodow FROM v_local)<>7
    OR extract(hour FROM v_local)<>21 THEN
   RETURN pg_catalog.jsonb_build_object(
     'status','outside_sunday_21_hour','credited',0);
 END IF;
 v_this_sunday := pg_catalog.date_trunc('week',v_local)
                   + interval '6 days 21 hours';
 v_sunday_utc := v_this_sunday AT TIME ZONE 'Asia/Riyadh';
 IF v_now < v_sunday_utc THEN
   RETURN pg_catalog.jsonb_build_object('status','not_due','credited',0);
 END IF;
 v_week_date := v_this_sunday::date;

 -- Prevent overlapping cron attempts and maintain one atomic accounting
 -- transaction per run. Manual claims serialize on each profiles row.
 PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo-svip-sunday:'||v_week_date::text,0)
 );
 FOR v_user IN
   SELECT p.id,p.svip_level,p.svip_last_claim
   FROM public.profiles p
   WHERE p.status='active'
     AND p.svip_level BETWEEN 1 AND 10
     AND p.svip_cycle_start IS NOT NULL
     AND p.svip_cycle_start <= v_sunday_utc
     AND p.svip_cycle_start + interval '90 days' > v_now
     AND p.svip_last_claim IS DISTINCT FROM v_week_date
   ORDER BY p.id
   FOR UPDATE OF p SKIP LOCKED
 LOOP
   BEGIN
     SELECT coins INTO v_amount
     FROM public.svip_friday_rewards
     WHERE level=v_user.svip_level;
     IF v_amount IS NULL OR v_amount<=0 THEN
       RAISE EXCEPTION 'SVIP reward catalog missing for current tier';
     END IF;
     v_ledger_id := NULL;
     INSERT INTO public.ledger
       (user_id,kind,coin_delta,diamond_delta,idempotency_key,ref)
     VALUES(
       v_user.id,'svip_friday',v_amount,0,
       'svip-'||v_week_date::text,
       pg_catalog.jsonb_build_object(
         'level',v_user.svip_level,'weekly_sunday',v_week_date,
         'schedule','Sunday 21:00 Asia/Riyadh','source','automatic')
     )
     ON CONFLICT (user_id,idempotency_key,kind) DO NOTHING
     RETURNING id INTO v_ledger_id;
     IF v_ledger_id IS NULL THEN
       -- Historical/manual row already exists; align claim flag, never
       -- create a second ledger credit.
       UPDATE public.profiles
       SET svip_last_claim=v_week_date WHERE id=v_user.id;
       v_already := v_already+1;
       CONTINUE;
     END IF;
     v_wallet_id:=NULL;
     UPDATE public.wallets SET coins=coins+v_amount
     WHERE user_id=v_user.id RETURNING user_id INTO v_wallet_id;
     IF v_wallet_id IS NULL THEN
       RAISE EXCEPTION 'SVIP member wallet not available';
     END IF;
     UPDATE public.profiles SET svip_last_claim=v_week_date
     WHERE id=v_user.id;
     v_count:=v_count+1;
     v_total:=v_total+v_amount;
   EXCEPTION WHEN OTHERS THEN
     -- Per-user subtransaction rolls back ledger, balance and claim flag
     -- together; one damaged account must not cancel all other payouts.
     v_failed:=v_failed+1;
     RAISE WARNING 'SVIP weekly payout skipped one account (SQLSTATE %)',
       SQLSTATE;
   END;
 END LOOP;

 INSERT INTO nimzo_private.svip_sunday_payout_runs
  (week_sunday,credited_count,already_paid_count,failed_count,payout_coins,status)
 VALUES(v_week_date,v_count,v_already,v_failed,v_total,
    CASE WHEN v_failed=0 THEN 'succeeded' ELSE 'partial_failure' END);
 RETURN pg_catalog.jsonb_build_object(
   'status',CASE WHEN v_failed=0 THEN 'succeeded' ELSE 'partial_failure' END,
   'week_sunday',v_week_date,'credited',v_count,
   'already_paid',v_already,'failed',v_failed,'coins',v_total);
END;
$reward$;

REVOKE ALL ON FUNCTION nimzo_private.pay_svip_sunday_rewards()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION nimzo_private.pay_svip_sunday_rewards() TO postgres;

-- pg_cron runs in UTC. Four safe slots provide limited same-hour retries.
-- cron.schedule(jobname, schedule, command) replaces the named job on
-- repeated migrations; no duplicate jobs are created.
SELECT cron.schedule(
 'nimzo_svip_sunday_21_riyadh',
 '0,15,30,45 18 * * 0',
 'SELECT nimzo_private.pay_svip_sunday_rewards();'
);
COMMIT;
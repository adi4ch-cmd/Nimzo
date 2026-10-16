-- Repair NIMZO Charm progress only; no wallet, coin or ledger mutations.
-- Historical self-gift diamond payouts already exist in the authoritative
-- ledger, but track_lifetime_events excluded them from Charm level progress.
-- Before the 2026-10-16 45% settlement change, older self gifts were NOT
-- credited diamonds; therefore NEVER backfill by summing gift_events.
-- Only previously credited gift_received / moment_gift_received ledger deltas
-- are eligible to count as Charm progress.
BEGIN;
SET LOCAL lock_timeout = '10s';

CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS nimzo_private.charm_progress_repair_backup_v1 (
  user_id uuid PRIMARY KEY,
  previous_charm_diamonds bigint NOT NULL,
  already_paid_gift_diamonds bigint NOT NULL,
  captured_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON TABLE nimzo_private.charm_progress_repair_backup_v1
  FROM PUBLIC, anon, authenticated;
ALTER TABLE nimzo_private.charm_progress_repair_backup_v1
  ENABLE ROW LEVEL SECURITY;

-- Keep the original trigger definition for a reversible, auditable repair.
CREATE TABLE IF NOT EXISTS nimzo_private.charm_progress_trigger_backup_v1 (
  function_name text PRIMARY KEY,
  definition text NOT NULL,
  captured_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON TABLE nimzo_private.charm_progress_trigger_backup_v1
  FROM PUBLIC, anon, authenticated;
ALTER TABLE nimzo_private.charm_progress_trigger_backup_v1
  ENABLE ROW LEVEL SECURITY;
INSERT INTO nimzo_private.charm_progress_trigger_backup_v1
  (function_name, definition)
SELECT 'public.track_lifetime_events()',
  pg_get_functiondef('public.track_lifetime_events()'::regprocedure)
ON CONFLICT (function_name) DO NOTHING;

-- Preserve pre-repair values before changing any account counter.
-- No ledger/purchase/wallet rows are modified.
INSERT INTO nimzo_private.charm_progress_repair_backup_v1
  (user_id, previous_charm_diamonds, already_paid_gift_diamonds)
SELECT
  p.id,
  COALESCE(p.charm_diamonds, 0),
  COALESCE((
    SELECT SUM(GREATEST(l.diamond_delta, 0))
    FROM public.ledger l
    WHERE l.user_id = p.id
      AND l.kind IN ('gift_received', 'moment_gift_received')
  ), 0)::bigint
FROM public.profiles p
ON CONFLICT (user_id) DO NOTHING;

-- A single verified gift event currently updates Wealth correctly but ignores
-- Charm when a user gifts themself, although send_gift/send_moment_gift now
-- pay 45% diamonds for self and other receivers alike.
-- Retain the original trigger's other behavior (room totals, Wealth,
-- Moment likes/comments, SECURITY DEFINER signature, ownership and grants).
DO $fix$
DECLARE
  v_sql text;
  v_old text := 'case when new.sender_id<>new.receiver_id then new.total_coins*45/100 else 0 end';
BEGIN
  SELECT pg_get_functiondef('public.track_lifetime_events()'::regprocedure)
    INTO v_sql;
  IF v_sql IS NULL THEN
    RAISE EXCEPTION 'track_lifetime_events() is missing';
  END IF;
  IF position(v_old IN v_sql) > 0 THEN
    EXECUTE replace(v_sql, v_old, 'new.total_coins*45/100');
  ELSIF position('charm_diamonds=charm_diamonds+new.total_coins*45/100' IN v_sql) = 0 THEN
    RAISE EXCEPTION 'Unexpected charm progress trigger; manual review required';
  END IF;
  -- Reject rollout if the actual settlement functions no longer pay
  -- recipient diamonds on self gifts. No silent cosmetic progress grants.
  IF position('diamond_credit:=total*45/100;' IN
    pg_get_functiondef('public.send_gift(uuid,uuid,uuid,integer,text)'::regprocedure)) = 0
     OR position('diamond_credit:=total*45/100;' IN
    pg_get_functiondef('public.send_moment_gift(uuid,uuid,uuid,integer,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'Gift settlement differs from expected 45%% receiver credit';
  END IF;
END
$fix$;

-- Backfill the PROGRESS counter, not the wallet, using actual paid diamonds
-- recorded in the ledger. GREATEST prevents reducing or double-adding
-- counters that already reflect historical gifts.
WITH verified AS (
  SELECT user_id,
    SUM(GREATEST(diamond_delta, 0))::bigint AS credited_diamonds
  FROM public.ledger
  WHERE kind IN ('gift_received', 'moment_gift_received')
  GROUP BY user_id
)
UPDATE public.profiles p
SET charm_diamonds = GREATEST(
  COALESCE(p.charm_diamonds, 0), v.credited_diamonds
)
FROM verified v
WHERE p.id = v.user_id
  AND COALESCE(p.charm_diamonds, 0) < v.credited_diamonds;

-- Guard audit: original Charm progress is never lost, all audited paid
-- diamonds are covered, and no old paid membership state is reactivated.
DO $verify$
BEGIN
 IF EXISTS (
  SELECT 1 FROM nimzo_private.charm_progress_repair_backup_v1 b
  JOIN public.profiles p ON p.id=b.user_id
  WHERE COALESCE(p.charm_diamonds,0)<b.previous_charm_diamonds
     OR COALESCE(p.charm_diamonds,0)<b.already_paid_gift_diamonds
 ) THEN
   RAISE EXCEPTION 'Historical gift progress preservation failed';
 END IF;
 IF EXISTS (
  SELECT 1 FROM public.profiles
  WHERE COALESCE(vip_level,0)<>0 OR COALESCE(svip_level,0)<>0
 ) THEN
   RAISE EXCEPTION 'Retired VIP/SVIP entitlement unexpectedly active';
 END IF;
END
$verify$;
NOTIFY pgrst, 'reload schema';
COMMIT;

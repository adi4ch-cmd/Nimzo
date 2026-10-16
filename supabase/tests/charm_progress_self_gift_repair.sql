-- Read-only assertions for the self-gift Charm progress repair.
-- Run AFTER the migration. No gift, wallet, account or financial mutation.
BEGIN;

DO $test$
DECLARE
  def text;
  missing integer;
BEGIN
  SELECT pg_get_functiondef('public.track_lifetime_events()'::regprocedure)
    INTO def;
  IF position('charm_diamonds=charm_diamonds+new.total_coins*45/100' IN def) = 0 THEN
    RAISE EXCEPTION 'Self gifts still excluded from Charm progress trigger';
  END IF;

  -- Confirm nobody has less Charm progress than their historically
  -- credited, unspent-or-exchanged received gift diamonds.
  SELECT count(*) INTO missing FROM public.profiles p
  JOIN (
    SELECT user_id, SUM(GREATEST(diamond_delta, 0))::bigint AS earned
    FROM public.ledger
    WHERE kind IN ('gift_received', 'moment_gift_received')
    GROUP BY user_id
  ) v ON v.user_id = p.id
  WHERE p.charm_diamonds < v.earned;
  IF missing <> 0 THEN
    RAISE EXCEPTION 'Some profiles have uncounted verified diamonds: %',missing;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles'
      AND column_name='charm_level' AND is_generated='ALWAYS'
  ) THEN
    RAISE EXCEPTION 'Charm level is not database-generated';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM nimzo_private.charm_progress_repair_backup_v1
  ) THEN
    RAISE EXCEPTION 'Missing pre-migration Charm progress backup';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE vip_level <> 0 OR svip_level <> 0
  ) THEN
    RAISE EXCEPTION 'Retired VIP/SVIP status restored';
  END IF;
END
$test$;

ROLLBACK;

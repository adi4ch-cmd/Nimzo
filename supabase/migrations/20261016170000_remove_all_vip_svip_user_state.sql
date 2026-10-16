-- NIMZO: completely remove both FREE VIP and SVIP from active user records.
-- Also clear the remaining legacy VIP/SVIP claim dates. Do not touch user
-- accounts, coins, diamonds, gifts, purchased store medals, or financial logs.
-- Legacy disabled membership columns remain for old-schema compatibility.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC, anon, authenticated;

-- Aggregate audit only: NEVER store a new copy of deleted membership
-- assignments or user identifiers.
CREATE TABLE IF NOT EXISTS nimzo_private.membership_removal_audit_v2 (
  change_id text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  removed_free_membership_rows bigint NOT NULL,
  cleared_legacy_user_rows bigint NOT NULL,
  preserved_profiles bigint NOT NULL,
  preserved_wallets bigint NOT NULL,
  preserved_ledger_rows bigint NOT NULL,
  preserved_gift_events bigint NOT NULL
);
REVOKE ALL ON nimzo_private.membership_removal_audit_v2
  FROM PUBLIC, anon, authenticated;
ALTER TABLE nimzo_private.membership_removal_audit_v2 ENABLE ROW LEVEL SECURITY;

DO $purge$
DECLARE
  v_free_rows bigint := 0;
  v_legacy_rows bigint := 0;
  v_profiles bigint;
  v_wallets bigint;
  v_ledger bigint;
  v_gifts bigint;
  v_coins numeric;
  v_diamonds numeric;
BEGIN
  -- These guard values are read-only. No financial tables are modified.
  SELECT count(*) INTO v_profiles FROM public.profiles;
  SELECT count(*),coalesce(sum(coins),0),coalesce(sum(diamonds),0)
    INTO v_wallets,v_coins,v_diamonds FROM public.wallets;
  SELECT count(*) INTO v_ledger FROM public.ledger;
  SELECT count(*) INTO v_gifts FROM public.gift_events;

  IF to_regclass('public.free_memberships') IS NOT NULL THEN
    SELECT count(*) INTO v_free_rows FROM public.free_memberships;
  END IF;
  SELECT count(*) INTO v_legacy_rows FROM public.profiles
    WHERE vip_level<>0 OR svip_level<>0
       OR vip_expires_at IS NOT NULL OR svip_cycle_start IS NOT NULL
       OR svip_cycle_cents<>0
       OR vip_last_claim IS NOT NULL OR svip_last_claim IS NOT NULL;

  -- Remove the ability of old app builds to activate the retired feature
  -- FIRST, then delete the entire free membership table and its users' rows.
  DROP FUNCTION IF EXISTS public.activate_free_membership(text,integer);
  DROP TABLE IF EXISTS public.free_memberships;

  -- Clear only VIP/SVIP-specific fields. Preserve the profile row, ID,
  -- level progress, family/social state, and every wallet/ledger entry.
  UPDATE public.profiles SET
    vip_level=0,
    vip_expires_at=NULL,
    vip_last_claim=NULL,
    svip_level=0,
    svip_cycle_start=NULL,
    svip_cycle_cents=0,
    svip_last_claim=NULL
  WHERE vip_level<>0 OR svip_level<>0
     OR vip_expires_at IS NOT NULL OR svip_cycle_start IS NOT NULL
     OR svip_cycle_cents<>0
     OR vip_last_claim IS NOT NULL OR svip_last_claim IS NOT NULL;

  -- Gift settlement remains usable without paid VIP/SVIP tier restrictions.
  UPDATE public.gifts SET min_vip=0,min_svip=0
  WHERE min_vip<>0 OR min_svip<>0;

  IF to_regclass('public.free_memberships') IS NOT NULL
     OR to_regprocedure('public.activate_free_membership(text,integer)') IS NOT NULL
     OR EXISTS(SELECT 1 FROM public.profiles
       WHERE vip_level<>0 OR svip_level<>0
         OR vip_expires_at IS NOT NULL OR svip_cycle_start IS NOT NULL
         OR svip_cycle_cents<>0
         OR vip_last_claim IS NOT NULL OR svip_last_claim IS NOT NULL) THEN
     RAISE EXCEPTION 'Membership removal failed: active user state remains';
  END IF;
  IF (SELECT count(*) FROM public.profiles)<>v_profiles
     OR (SELECT count(*) FROM public.wallets)<>v_wallets
     OR (SELECT coalesce(sum(coins),0) FROM public.wallets)<>v_coins
     OR (SELECT coalesce(sum(diamonds),0) FROM public.wallets)<>v_diamonds
     OR (SELECT count(*) FROM public.ledger)<>v_ledger
     OR (SELECT count(*) FROM public.gift_events)<>v_gifts THEN
     RAISE EXCEPTION 'Unrelated accounts or economy data changed; rollback';
  END IF;

  INSERT INTO nimzo_private.membership_removal_audit_v2(
    change_id,removed_free_membership_rows,cleared_legacy_user_rows,
    preserved_profiles,preserved_wallets,preserved_ledger_rows,
    preserved_gift_events
  ) VALUES (
    'remove-free-vip-svip-20261016',v_free_rows,v_legacy_rows,
    v_profiles,v_wallets,v_ledger,v_gifts
  ) ON CONFLICT(change_id) DO NOTHING;
END;
$purge$;

NOTIFY pgrst, 'reload schema';
COMMIT;

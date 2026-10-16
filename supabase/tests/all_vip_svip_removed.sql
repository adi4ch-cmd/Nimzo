-- Run read-only after the VIP/SVIP retirement migration. No user data changes.
BEGIN;
DO $test$
BEGIN
 IF to_regclass('public.free_memberships') IS NOT NULL THEN
  RAISE EXCEPTION 'Free VIP/SVIP table still present';
 END IF;
 IF to_regprocedure('public.activate_free_membership(text,integer)') IS NOT NULL THEN
  RAISE EXCEPTION 'Free VIP/SVIP activation still enabled';
 END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE
   vip_level<>0 OR svip_level<>0 OR vip_expires_at IS NOT NULL
   OR svip_cycle_start IS NOT NULL OR svip_cycle_cents<>0
   OR vip_last_claim IS NOT NULL OR svip_last_claim IS NOT NULL) THEN
  RAISE EXCEPTION 'VIP/SVIP user assignment or claim date remains';
 END IF;
 IF EXISTS(SELECT 1 FROM public.gifts WHERE min_vip<>0 OR min_svip<>0) THEN
  RAISE EXCEPTION 'Retired membership still restricts a gift';
 END IF;
 IF NOT EXISTS(
    SELECT 1 FROM nimzo_private.membership_removal_audit_v2
    WHERE change_id='remove-free-vip-svip-20261016'
 ) THEN
  RAISE EXCEPTION 'No aggregate removal audit record';
 END IF;
END $test$;
ROLLBACK;

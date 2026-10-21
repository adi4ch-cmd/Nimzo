-- Behavior suite for a disposable database ONLY. Run after the fixture and
-- migration with psql -v ON_ERROR_STOP=1. All account/financial fixtures roll back.
BEGIN;
INSERT INTO public.profiles(id,display_name) VALUES
 ('00000000-0000-4000-8000-000000000901','Membership purchase fixture'),
 ('00000000-0000-4000-8000-000000000902','Recharge fixture'),
 ('00000000-0000-4000-8000-000000000903','No earned membership');
INSERT INTO public.wallets(user_id,coins,diamonds) VALUES
 ('00000000-0000-4000-8000-000000000901',2000000000,123),
 ('00000000-0000-4000-8000-000000000902',0,456),
 ('00000000-0000-4000-8000-000000000903',0,789);
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000901',true);
SET LOCAL ROLE authenticated;
DO $purchase$
DECLARE a jsonb; b jsonb; expiry timestamptz; before_coins bigint;
BEGIN
 IF (public.vip_status()->>'purchases_enabled')::bool IS NOT TRUE OR public.vip_status()->>'retired'<>'false' THEN RAISE EXCEPTION 'Activation capability missing'; END IF;
 IF (SELECT count(*) FROM public.normal_vip_catalog)<>10 THEN RAISE EXCEPTION 'Catalog SELECT unavailable'; END IF;
 a:=public.purchase_normal_vip(1,'restore-first-purchase');
 b:=public.purchase_normal_vip(1,'restore-first-purchase');
 IF a->>'status'<>'ok' OR b->>'status'<>'replayed' OR public.vip_status()->>'vip_level'<>'1' THEN RAISE EXCEPTION 'Purchase/replay failed'; END IF;
 BEGIN
  PERFORM public.purchase_normal_vip(2,'restore-first-purchase');
  RAISE EXCEPTION 'Idempotency mismatch accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Purchase idempotency payload mismatch' THEN RAISE; END IF; END;
 expiry:=(public.vip_status()->>'vip_expires_at')::timestamptz;
 PERFORM public.purchase_normal_vip(1,'restore-renewal-purchase');
 IF (public.vip_status()->>'vip_expires_at')::timestamptz<>expiry+interval '30 days' THEN RAISE EXCEPTION 'Renewal did not extend expiry'; END IF;
 PERFORM public.purchase_normal_vip(10,'restore-tier-ten-purchase');
 IF public.vip_status()->>'vip_level'<>'10' OR (public.vip_status()->>'vip_expires_at')::timestamptz<>now()+interval '30 days' THEN RAISE EXCEPTION 'Tier ten purchase failed'; END IF;
 PERFORM public.claim_vip_daily();
 BEGIN PERFORM public.claim_vip_daily(); RAISE EXCEPTION 'Daily double claim accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'VIP reward already claimed today' THEN RAISE; END IF; END;
 PERFORM public.purchase_normal_vip(1,'restore-after-daily-purchase');
 IF public.vip_status()->>'vip_daily_claimed_today'<>'true' THEN RAISE EXCEPTION 'Purchase reset daily entitlement'; END IF;
 BEGIN UPDATE public.profiles SET vip_level=10 WHERE id=auth.uid(); RAISE EXCEPTION 'Client self-grant allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$purchase$;
RESET ROLE;
DO $accounting$
BEGIN
 IF (SELECT coins FROM public.wallets WHERE user_id=auth.uid())<>2000000000-1000000-1000000-600000000-1000000+9600000 THEN RAISE EXCEPTION 'Wallet purchase accounting mismatch'; END IF;
 IF (SELECT diamonds FROM public.wallets WHERE user_id=auth.uid())<>123 THEN RAISE EXCEPTION 'Diamonds modified'; END IF;
 IF (SELECT count(*) FROM public.ledger WHERE user_id=auth.uid() AND kind='vip_purchase')<>4 THEN RAISE EXCEPTION 'Replay created ledger duplicate'; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id='00000000-0000-4000-8000-000000000903' AND (vip_level<>0 OR svip_level<>0)) THEN RAISE EXCEPTION 'Unearned membership granted'; END IF;
END;
$accounting$;
-- Insufficient funds must not partially activate or debit an account.
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000903',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.purchase_normal_vip(1,'restore-insufficient-balance'); RAISE EXCEPTION 'Insufficient purchase accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'Insufficient coins' THEN RAISE; END IF; END;
 IF public.vip_status()->>'vip_level'<>'0' THEN RAISE EXCEPTION 'Failed purchase granted membership'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000901',true);
-- Effective status and entrance events honor expiry and account restrictions.
INSERT INTO public.room_members(room_id,user_id) VALUES(gen_random_uuid(),'00000000-0000-4000-8000-000000000901');
UPDATE public.profiles SET vip_expires_at=now()-interval '1 second' WHERE id=auth.uid();
INSERT INTO public.room_members(room_id,user_id) VALUES(gen_random_uuid(),'00000000-0000-4000-8000-000000000901');
DO $$ BEGIN
 IF public.vip_status()->>'vip_level'<>'0' OR public.phoenix_membership(auth.uid())->>'vip_level'<>'0' THEN RAISE EXCEPTION 'Expired VIP active'; END IF;
 IF (SELECT count(*) FROM public.phoenix_room_entries WHERE user_id=auth.uid())<>1 THEN RAISE EXCEPTION 'Entry entitlement not enforced'; END IF;
END $$;
-- Verified recharge stays service-only and accrues prospectively exactly once.
SET LOCAL ROLE service_role;
DO $recharge$
DECLARE a jsonb; b jsonb;
BEGIN
 a:=public.apply_recharge('00000000-0000-4000-8000-000000000902','google_play','restore-receipt-1','approved-small');
 b:=public.apply_recharge('00000000-0000-4000-8000-000000000902','google_play','restore-receipt-1','approved-small');
 IF a->>'status'<>'credited' OR b->>'status'<>'replayed' THEN RAISE EXCEPTION 'Recharge replay failed'; END IF;
 BEGIN PERFORM public.apply_recharge('00000000-0000-4000-8000-000000000903','google_play','restore-receipt-1','approved-small'); RAISE EXCEPTION 'Other-user receipt accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'purchase belongs to another account' THEN RAISE; END IF; END;
 BEGIN PERFORM public.apply_recharge('00000000-0000-4000-8000-000000000902','google_play','restore-receipt-1','approved-large'); RAISE EXCEPTION 'Other-product receipt accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'purchase product mismatch' THEN RAISE; END IF; END;
END;
$recharge$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT (svip_level,svip_cycle_cents)<>(1,5000) FROM public.profiles WHERE id='00000000-0000-4000-8000-000000000902') THEN RAISE EXCEPTION 'SVIP recharge accrual mismatch'; END IF;
 IF (SELECT coins<>500000 OR diamonds<>456 FROM public.wallets WHERE user_id='00000000-0000-4000-8000-000000000902') THEN RAISE EXCEPTION 'Recharge financial mismatch'; END IF;
END $$;
UPDATE public.profiles SET svip_cycle_start=now()-interval '91 days',svip_cycle_cents=50000000,svip_level=10 WHERE id='00000000-0000-4000-8000-000000000902';
SET LOCAL ROLE service_role;
SELECT public.apply_recharge('00000000-0000-4000-8000-000000000902','google_play','restore-receipt-new-cycle','approved-small');
RESET ROLE;
DO $$ BEGIN
 IF (SELECT (svip_level,svip_cycle_cents)<>(1,5000) FROM public.profiles WHERE id='00000000-0000-4000-8000-000000000902') THEN RAISE EXCEPTION 'Expired SVIP cycle was not reset prospectively'; END IF;
END $$;
-- Qualify before the latest Sunday 21:00 Riyadh boundary, then claim once.
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000902',true);
UPDATE public.profiles SET svip_cycle_start=(CASE WHEN (now() AT TIME ZONE 'Asia/Riyadh')<date_trunc('week',now() AT TIME ZONE 'Asia/Riyadh')+interval '6 days 21 hours' THEN date_trunc('week',now() AT TIME ZONE 'Asia/Riyadh')+interval '6 days 21 hours'-interval '7 days' ELSE date_trunc('week',now() AT TIME ZONE 'Asia/Riyadh')+interval '6 days 21 hours' END AT TIME ZONE 'Asia/Riyadh')-interval '1 day' WHERE id=auth.uid();
SET LOCAL ROLE authenticated;
SELECT public.claim_svip_friday();
DO $$ BEGIN
 BEGIN PERFORM public.claim_svip_friday(); RAISE EXCEPTION 'Weekly double claim accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'SVIP weekly reward already claimed' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
UPDATE public.profiles SET svip_cycle_start=now()-interval '90 days' WHERE id=auth.uid();
DO $$ BEGIN
 IF public.vip_status()->>'svip_level'<>'0' OR public.vip_status()->>'svip_cycle_cents'<>'0' OR public.phoenix_membership(auth.uid())->>'svip_level'<>'0' THEN RAISE EXCEPTION 'Expired SVIP remained active'; END IF;
 IF has_function_privilege('authenticated','public.apply_recharge(uuid,text,text,text)','EXECUTE') OR has_function_privilege('anon','public.purchase_normal_vip(integer,text)','EXECUTE') OR has_function_privilege('authenticated','public.activate_vip(uuid,integer)','EXECUTE') OR has_function_privilege('authenticated','nimzo_private.pay_svip_sunday_rewards()','EXECUTE') THEN RAISE EXCEPTION 'RPC privilege escalation'; END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='nimzo_svip_sunday_21_riyadh' AND active AND schedule='0,15,30,45 18 * * 0') THEN RAISE EXCEPTION 'Payout scheduler not enabled'; END IF;
 IF extract(isodow FROM now() AT TIME ZONE 'Asia/Riyadh')<>7 OR extract(hour FROM now() AT TIME ZONE 'Asia/Riyadh')<>21 THEN
  IF nimzo_private.pay_svip_sunday_rewards()->>'status'<>'outside_sunday_21_hour' THEN RAISE EXCEPTION 'Out-of-window automatic payout'; END IF;
 END IF;
END $$;
ROLLBACK;

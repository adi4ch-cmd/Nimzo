BEGIN;
INSERT INTO auth.users(id,email) VALUES
 ('00000000-0000-4000-8000-000000000951','self-profile-951@example.invalid'),
 ('00000000-0000-4000-8000-000000000952','self-profile-952@example.invalid');
INSERT INTO public.gifts(id,name,category,coin_price,min_vip,min_svip,active)
 VALUES('00000000-0000-4000-8000-000000000953','Self gift fixture','classic',1000,0,0,true);
UPDATE public.wallets SET coins=10000 WHERE user_id='00000000-0000-4000-8000-000000000951';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000951',true);
DO $$ DECLARE a jsonb; BEGIN
 a:=public.send_profile_gift(auth.uid(),'00000000-0000-4000-8000-000000000953',1,'self-profile-fixture');
 IF a->>'diamonds' IS DISTINCT FROM '450' THEN RAISE EXCEPTION 'Incorrect self gift credit'; END IF;
 a:=public.send_profile_gift(auth.uid(),'00000000-0000-4000-8000-000000000953',1,'self-profile-fixture');
 IF a->>'status' IS DISTINCT FROM 'replayed' THEN RAISE EXCEPTION 'Self gift retry not replayed'; END IF;
 BEGIN
  PERFORM public.send_profile_gift(auth.uid(),'00000000-0000-4000-8000-000000000953',2,'self-profile-fixture');
  RAISE EXCEPTION 'Changed self gift retry accepted';
 EXCEPTION WHEN raise_exception THEN IF sqlerrm<>'idempotency payload mismatch' THEN RAISE; END IF; END;
 PERFORM public.send_profile_gift('00000000-0000-4000-8000-000000000952','00000000-0000-4000-8000-000000000953',1,'other-profile-fixture');
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT coins FROM public.wallets WHERE user_id='00000000-0000-4000-8000-000000000951')<>8000
 OR (SELECT diamonds FROM public.wallets WHERE user_id='00000000-0000-4000-8000-000000000951')<>450
 OR (SELECT diamonds FROM public.wallets WHERE user_id='00000000-0000-4000-8000-000000000952')<>450 THEN
  RAISE EXCEPTION 'Incorrect wallets or duplicate settlement';
 END IF;
 IF (SELECT count(*) FROM public.gift_events WHERE gift_id='00000000-0000-4000-8000-000000000953')<>2 THEN
  RAISE EXCEPTION 'Retry created duplicate gift';
 END IF;
END $$;
SELECT 'PASS self-profile gift credits 45 percent once; normal profile gifting preserved' result;
ROLLBACK;

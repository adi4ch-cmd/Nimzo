-- Run inside BEGIN/ROLLBACK. No permanent user fixtures or financial mutations.
DO $test$
DECLARE v_user uuid; v_before jsonb; v_after jsonb; v_rpc text;
BEGIN
 IF EXISTS(SELECT 1 FROM public.profiles WHERE vip_level<>0 OR svip_level<>0 OR vip_expires_at IS NOT NULL OR svip_cycle_start IS NOT NULL OR svip_cycle_cents<>0) THEN
  RAISE EXCEPTION 'VIP/SVIP assignments still exist';
 END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='nimzo_svip_sunday_21_riyadh' AND active) THEN RAISE EXCEPTION 'SVIP payout job still active'; END IF;
 IF EXISTS(SELECT 1 FROM public.gifts WHERE min_vip<>0 OR min_svip<>0) THEN RAISE EXCEPTION 'Gift membership locks still exist'; END IF;
 IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.room_members'::regclass AND tgname='phoenix_room_entry') THEN RAISE EXCEPTION 'Membership entry trigger remains'; END IF;
 IF pg_catalog.has_schema_privilege('authenticated','nimzo_private','USAGE') OR pg_catalog.has_schema_privilege('anon','nimzo_private','USAGE') THEN RAISE EXCEPTION 'Private backup schema exposed'; END IF;
 SELECT id INTO v_user FROM public.profiles WHERE status='active' LIMIT 1;
 IF v_user IS NULL THEN RAISE EXCEPTION 'Need one active profile for rollback tests'; END IF;
 SELECT jsonb_build_object('wallets',(SELECT jsonb_agg(to_jsonb(w) ORDER BY user_id) FROM public.wallets w),'ledger',(SELECT count(*) FROM public.ledger),'purchases',(SELECT count(*) FROM public.purchases)) INTO v_before;
 PERFORM set_config('request.jwt.claim.sub',v_user::text,true);
 FOREACH v_rpc IN ARRAY ARRAY['SELECT public.purchase_normal_vip(10,''retirement-regression'')','SELECT public.activate_vip('''||v_user||'''::uuid,10)','SELECT public.claim_vip_daily()','SELECT public.claim_svip_friday()'] LOOP
  BEGIN
   EXECUTE v_rpc;
   RAISE EXCEPTION 'Retired RPC unexpectedly succeeded: %',v_rpc;
  EXCEPTION WHEN SQLSTATE '0A000' THEN NULL;
  END;
 END LOOP;
 BEGIN
  UPDATE public.profiles SET vip_level=10,vip_expires_at=now()+interval '1 day' WHERE id=v_user;
  RAISE EXCEPTION 'VIP regrant accepted';
 EXCEPTION WHEN SQLSTATE '0A000' THEN NULL;
 END;
 BEGIN
  UPDATE public.profiles SET svip_level=10,svip_cycle_start=now(),svip_cycle_cents=999999 WHERE id=v_user;
  RAISE EXCEPTION 'SVIP regrant accepted';
 EXCEPTION WHEN SQLSTATE '0A000' THEN NULL;
 END;
 IF public.phoenix_membership(v_user)->>'vip_level'<>'0' OR public.phoenix_membership(v_user)->>'svip_level'<>'0' THEN RAISE EXCEPTION 'Retired membership reported active'; END IF;
 IF public.vip_status()->>'svip_auto_enabled'<>'false' THEN RAISE EXCEPTION 'Status still advertises automatic rewards'; END IF;
 IF nimzo_private.pay_svip_sunday_rewards()->>'credited'<>'0' THEN RAISE EXCEPTION 'Retired scheduler credited rewards'; END IF;
 SELECT jsonb_build_object('wallets',(SELECT jsonb_agg(to_jsonb(w) ORDER BY user_id) FROM public.wallets w),'ledger',(SELECT count(*) FROM public.ledger),'purchases',(SELECT count(*) FROM public.purchases)) INTO v_after;
 IF v_before IS DISTINCT FROM v_after THEN RAISE EXCEPTION 'Retirement tests mutated finances'; END IF;
END;
$test$;
-- Isolated rollback fixtures prove financial credit still works without SVIP.
DO $recharge$
DECLARE u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); pk public.recharge_packages;
 v_coins bigint; v_diamonds bigint; a jsonb; b jsonb; tx text:='retirement-'||gen_random_uuid();
BEGIN
 BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@retirement.example.invalid'),(other_user,other_user||'@retirement.example.invalid');
  SELECT * INTO pk FROM public.recharge_packages WHERE active ORDER BY usd_cents DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'No active recharge package to test'; END IF;
  SELECT coins,diamonds INTO v_coins,v_diamonds FROM public.wallets WHERE user_id=u;
  IF v_coins IS NULL THEN RAISE EXCEPTION 'Fixture wallet missing'; END IF;
  a:=public.apply_recharge(u,'google_play',tx,pk.product_id);
  b:=public.apply_recharge(u,'google_play',tx,pk.product_id);
  IF a->>'status'<>'credited' OR b->>'status'<>'replayed' THEN RAISE EXCEPTION 'Recharge/replay contract broken'; END IF;
  IF (SELECT coins FROM public.wallets WHERE user_id=u)<>v_coins+pk.coins OR (SELECT diamonds FROM public.wallets WHERE user_id=u)<>v_diamonds THEN RAISE EXCEPTION 'Recharge financial credit changed'; END IF;
  IF (SELECT count(*) FROM public.ledger WHERE user_id=u AND kind='recharge')<>1 THEN RAISE EXCEPTION 'Duplicate recharge ledger'; END IF;
  IF EXISTS(SELECT 1 FROM public.profiles WHERE id=u AND (vip_level<>0 OR svip_level<>0 OR svip_cycle_cents<>0 OR svip_cycle_start IS NOT NULL)) THEN RAISE EXCEPTION 'Recharge regranted membership'; END IF;
  BEGIN
   PERFORM public.apply_recharge(other_user,'google_play',tx,pk.product_id);
   RAISE EXCEPTION 'Cross-account receipt accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'purchase belongs to another account' THEN RAISE; END IF; END;
  IF has_function_privilege('authenticated','public.apply_recharge(uuid,text,text,text)','EXECUTE') OR has_function_privilege('anon','public.purchase_normal_vip(integer,text)','EXECUTE') THEN RAISE EXCEPTION 'RPC role boundary broken'; END IF;
  -- Roll back fixture rows and credits even when caller forgets ROLLBACK.
  RAISE EXCEPTION 'fixture rollback' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
 END;
END;
$recharge$;

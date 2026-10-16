-- Authorized complete retirement; no replacement entitlement is created.
-- Private logical data/definition snapshot precedes every reset. Original snapshot
-- is immutable across retries. Financial/history rows are never deleted or edited.
BEGIN;
SET LOCAL lock_timeout='10s';
CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS nimzo_private.membership_retirement_backup (
 version text NOT NULL,
 object_name text NOT NULL,
 captured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 payload jsonb NOT NULL,
 PRIMARY KEY(version,object_name)
);
REVOKE ALL ON TABLE nimzo_private.membership_retirement_backup FROM PUBLIC,anon,authenticated;
ALTER TABLE nimzo_private.membership_retirement_backup ENABLE ROW LEVEL SECURITY;
CREATE TEMP TABLE IF NOT EXISTS nimzo_retirement_guard(table_name text PRIMARY KEY,payload jsonb NOT NULL) ON COMMIT DROP;
TRUNCATE pg_temp.nimzo_retirement_guard;
DO $backup$
DECLARE r record; v_data jsonb; v_guard jsonb;
BEGIN
 -- Lock in deterministic order, including finances, so the preservation check
 -- cannot mistake a simultaneous legitimate purchase for data corruption.
 FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r' ORDER BY c.relname LOOP
  EXECUTE format('LOCK TABLE public.%I IN SHARE ROW EXCLUSIVE MODE',r.relname);
 END LOOP;
 FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r' ORDER BY c.relname LOOP
  EXECUTE format('SELECT coalesce(jsonb_agg(j ORDER BY j::text),''[]''::jsonb) FROM (SELECT to_jsonb(t) j FROM public.%I t) q',r.relname) INTO v_data;
  INSERT INTO nimzo_private.membership_retirement_backup(version,object_name,payload)
  VALUES('retire-vip-svip-v1','table:public.'||r.relname,v_data) ON CONFLICT DO NOTHING;
  SELECT coalesce(jsonb_agg(j ORDER BY j::text),'[]'::jsonb) INTO v_guard FROM (
   SELECT CASE r.relname
    WHEN 'profiles' THEN x-ARRAY['vip_level','vip_expires_at','svip_level','svip_cycle_start','svip_cycle_cents']
    WHEN 'gifts' THEN x-ARRAY['min_vip','min_svip']
    ELSE x END j FROM jsonb_array_elements(v_data) x
  ) q;
  INSERT INTO pg_temp.nimzo_retirement_guard VALUES(r.relname,v_guard);
 END LOOP;
 INSERT INTO nimzo_private.membership_retirement_backup(version,object_name,payload)
 SELECT 'retire-vip-svip-v1','function:'||p.oid::regprocedure::text,
 jsonb_build_object('definition',pg_get_functiondef(p.oid),'acl',p.proacl::text,'owner',pg_get_userbyid(p.proowner))
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('public','nimzo_private') AND p.prokind='f'
 ON CONFLICT DO NOTHING;
 INSERT INTO nimzo_private.membership_retirement_backup(version,object_name,payload)
 SELECT 'retire-vip-svip-v1','triggers',coalesce(jsonb_agg(jsonb_build_object('definition',pg_get_triggerdef(t.oid))),'[]'::jsonb)
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND NOT t.tgisinternal ON CONFLICT DO NOTHING;
 INSERT INTO nimzo_private.membership_retirement_backup(version,object_name,payload)
 SELECT 'retire-vip-svip-v1','cron',coalesce(jsonb_agg(to_jsonb(j)),'[]'::jsonb) FROM cron.job j ON CONFLICT DO NOTHING;
END;
$backup$;

-- Fail before touching wallets, even when a stale app invokes a retired API.
CREATE OR REPLACE FUNCTION public.purchase_normal_vip(p_tier integer,p_key text)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN RAISE EXCEPTION 'VIP and SVIP have been retired' USING ERRCODE='0A000'; END;
$f$;
CREATE OR REPLACE FUNCTION public.activate_vip(p_user uuid,p_level integer)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN RAISE EXCEPTION 'VIP and SVIP have been retired' USING ERRCODE='0A000'; END;
$f$;
CREATE OR REPLACE FUNCTION public.claim_vip_daily()
RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN RAISE EXCEPTION 'VIP and SVIP have been retired' USING ERRCODE='0A000'; END;
$f$;
CREATE OR REPLACE FUNCTION public.claim_svip_friday()
RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN RAISE EXCEPTION 'VIP and SVIP have been retired' USING ERRCODE='0A000'; END;
$f$;
-- Keep old grant boundaries; replacement bodies have no privileged data access.
REVOKE ALL ON FUNCTION public.purchase_normal_vip(integer,text),public.claim_vip_daily(),public.claim_svip_friday() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.purchase_normal_vip(integer,text),public.claim_vip_daily(),public.claim_svip_friday() TO authenticated;
REVOKE ALL ON FUNCTION public.activate_vip(uuid,integer) FROM PUBLIC,anon,authenticated;

-- Preserve receipt validation, exact replay checking and financial credit. Remove
-- only the legacy membership calculation after the credit.
CREATE OR REPLACE FUNCTION public.apply_recharge(p_user uuid,p_store text,p_txn text,p_product text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE pk public.recharge_packages; existing public.purchases;
BEGIN
 IF p_user IS NULL OR p_store NOT IN('google_play','app_store') OR nullif(trim(p_txn),'') IS NULL OR nullif(trim(p_product),'') IS NULL THEN RAISE EXCEPTION 'invalid purchase'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_store||':'||p_txn,0));
 SELECT * INTO pk FROM public.recharge_packages WHERE product_id=p_product;
 IF NOT FOUND THEN RAISE EXCEPTION 'unknown product'; END IF;
 SELECT * INTO existing FROM public.purchases WHERE store=p_store AND txn_id=p_txn;
 IF FOUND THEN
  IF existing.user_id<>p_user THEN RAISE EXCEPTION 'purchase belongs to another account'; END IF;
  IF (existing.product_id IS NOT NULL AND existing.product_id<>p_product) OR existing.usd_cents<>pk.usd_cents OR existing.coins<>pk.coins THEN RAISE EXCEPTION 'purchase product mismatch'; END IF;
  RETURN jsonb_build_object('status','replayed','coins',existing.coins,'product_id',p_product,'transaction_id',p_txn);
 END IF;
 IF NOT pk.active THEN RAISE EXCEPTION 'product unavailable'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=p_user AND status='active' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'account restricted'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.wallets WHERE user_id=p_user) THEN RAISE EXCEPTION 'wallet missing'; END IF;
 INSERT INTO public.purchases(store,txn_id,user_id,usd_cents,coins,product_id) VALUES(p_store,p_txn,p_user,pk.usd_cents,pk.coins,p_product);
 UPDATE public.wallets SET coins=coins+pk.coins WHERE user_id=p_user;
 INSERT INTO public.ledger(user_id,kind,coin_delta,ref,idempotency_key) VALUES(p_user,'recharge',pk.coins,jsonb_build_object('store',p_store,'product',p_product,'transaction_id',p_txn),p_store||':'||p_txn);
 RETURN jsonb_build_object('status','credited','coins',pk.coins,'product_id',p_product,'transaction_id',p_txn);
END;
$f$;
REVOKE ALL ON FUNCTION public.apply_recharge(uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_recharge(uuid,text,text,text) TO service_role;
DO $cron$
DECLARE r record;
BEGIN
 FOR r IN SELECT jobid FROM cron.job WHERE jobname='nimzo_svip_sunday_21_riyadh' LOOP
  PERFORM cron.alter_job(r.jobid,active:=false);
 END LOOP;
END;
$cron$;
CREATE OR REPLACE FUNCTION nimzo_private.pay_svip_sunday_rewards()
RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 SELECT pg_catalog.jsonb_build_object('status','retired','credited',0,'coins',0)
$f$;
DROP TRIGGER IF EXISTS phoenix_room_entry ON public.room_members;
CREATE OR REPLACE FUNCTION nimzo_private.phoenix_room_entry()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN RETURN NEW; END;
$f$;
CREATE OR REPLACE FUNCTION public.phoenix_membership(p_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT pg_catalog.jsonb_build_object('vip_level',0,'svip_level',0,'vip_expires_at',NULL,'svip_expires_at',NULL,'server_now',pg_catalog.now())
 WHERE auth.uid() IS NOT NULL
$f$;
CREATE OR REPLACE FUNCTION public.vip_status()
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT pg_catalog.jsonb_build_object('vip_level',0,'svip_level',0,'vip_expires_at',NULL,'svip_cycle_active',false,'svip_cycle_cents',0,'svip_auto_enabled',false,'retired',true)
 WHERE auth.uid() IS NOT NULL
$f$;

UPDATE public.profiles SET vip_level=0,vip_expires_at=NULL,svip_level=0,svip_cycle_start=NULL,svip_cycle_cents=0
WHERE vip_level<>0 OR vip_expires_at IS NOT NULL OR svip_level<>0 OR svip_cycle_start IS NOT NULL OR svip_cycle_cents<>0;
-- A database invariant also prevents privileged scripts or old service code from
-- regranting retired membership. Legitimate non-membership profile edits work.
CREATE OR REPLACE FUNCTION nimzo_private.reject_retired_membership()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF NEW.vip_level<>0 OR NEW.svip_level<>0 OR NEW.vip_expires_at IS NOT NULL OR NEW.svip_cycle_start IS NOT NULL OR NEW.svip_cycle_cents<>0 THEN
  RAISE EXCEPTION 'VIP and SVIP have been retired' USING ERRCODE='0A000';
 END IF;
 RETURN NEW;
END;
$f$;
REVOKE ALL ON FUNCTION nimzo_private.reject_retired_membership() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS reject_retired_membership ON public.profiles;
CREATE TRIGGER reject_retired_membership BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION nimzo_private.reject_retired_membership();
UPDATE public.gifts SET min_vip=0,min_svip=0 WHERE min_vip<>0 OR min_svip<>0;
-- Tier conditions in legacy gift RPCs now compare against zero. Gift prices,
-- settlement and event history are unchanged.
-- Remove dormant SVIP moderation exceptions without changing authorization.
DO $moderation$
DECLARE v_definition text;
BEGIN
 v_definition:=pg_get_functiondef('public.kick_member(uuid,uuid)'::regprocedure);
 v_definition:=replace(v_definition,'if tgt_svip>=5 and not is_adm then raise exception ''target is protected''; end if;','');
 IF v_definition ~* 'if tgt_svip\s*>=' THEN RAISE EXCEPTION 'Unrecognized legacy kick protection'; END IF;
 EXECUTE v_definition;
 v_definition:=pg_get_functiondef('public.moderate_room_member(uuid,uuid,boolean)'::regprocedure);
 v_definition:=replace(v_definition,'if target_svip>=5 and not public.is_admin() then raise exception ''target is protected'' using errcode=''42501''; end if;','');
 IF v_definition ~* 'if target_svip\s*>=' THEN RAISE EXCEPTION 'Unrecognized legacy moderation protection'; END IF;
 EXECUTE v_definition;
END;
$moderation$;

-- No client should continue to browse retired catalogs. Keep historical rows.
REVOKE ALL ON public.normal_vip_catalog,public.vip_daily_rewards,public.svip_thresholds,public.svip_friday_rewards FROM PUBLIC,anon,authenticated;
DO $preservation$
DECLARE r record; v_after jsonb;
BEGIN
 FOR r IN SELECT * FROM pg_temp.nimzo_retirement_guard ORDER BY table_name LOOP
  EXECUTE format('SELECT coalesce(jsonb_agg(j ORDER BY j::text),''[]''::jsonb) FROM (SELECT CASE %L WHEN ''profiles'' THEN to_jsonb(t)-ARRAY[''vip_level'',''vip_expires_at'',''svip_level'',''svip_cycle_start'',''svip_cycle_cents''] WHEN ''gifts'' THEN to_jsonb(t)-ARRAY[''min_vip'',''min_svip''] ELSE to_jsonb(t) END j FROM public.%I t) q',r.table_name,r.table_name) INTO v_after;
  IF v_after IS DISTINCT FROM r.payload THEN RAISE EXCEPTION 'Unrelated data changed in %; retirement rolled back',r.table_name; END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM nimzo_private.membership_retirement_backup WHERE version='retire-vip-svip-v1' AND object_name='table:public.profiles') THEN RAISE EXCEPTION 'Missing entitlement backup'; END IF;
END;
$preservation$;
NOTIFY pgrst,'reload schema';
COMMIT;

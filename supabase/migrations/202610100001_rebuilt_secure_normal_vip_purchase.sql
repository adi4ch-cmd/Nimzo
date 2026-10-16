-- NIMZO professional VIP 1–10 rebuild. Server-side coin purchase only.
-- Preserves SVIP fields, previous accounting, and user profiles.
CREATE TABLE IF NOT EXISTS public.normal_vip_catalog (
  tier integer PRIMARY KEY CHECK (tier BETWEEN 1 AND 10),
  coin_price bigint NOT NULL CHECK (coin_price > 0),
  duration_days integer NOT NULL DEFAULT 30 CHECK (duration_days BETWEEN 1 AND 365),
  updated_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON TABLE public.normal_vip_catalog FROM PUBLIC;
GRANT SELECT ON TABLE public.normal_vip_catalog TO authenticated;
ALTER TABLE public.normal_vip_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS normal_vip_catalog_read ON public.normal_vip_catalog;
CREATE POLICY normal_vip_catalog_read ON public.normal_vip_catalog
FOR SELECT TO authenticated USING (true);

INSERT INTO public.normal_vip_catalog(tier,coin_price,duration_days)
VALUES
(1,1000000,30),(2,3000000,30),(3,8000000,30),(4,15000000,30),
(5,30000000,30),(6,60000000,30),(7,100000000,30),
(8,200000000,30),(9,350000000,30),(10,600000000,30)
ON CONFLICT (tier) DO NOTHING;

CREATE OR REPLACE FUNCTION public.purchase_normal_vip(p_tier integer,p_key text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_coins bigint;
  v_days integer;
  v_existing jsonb;
  v_level integer;
  v_expiry timestamptz;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF p_tier NOT BETWEEN 1 AND 10 THEN RAISE EXCEPTION 'Invalid VIP tier'; END IF;
  IF p_key IS NULL OR length(trim(p_key))<8 OR length(p_key)>128 THEN
    RAISE EXCEPTION 'Invalid purchase idempotency key';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('normal_vip:' || v_user::text || ':' || p_key, 0)
  );
  SELECT ref INTO v_existing
  FROM public.ledger
  WHERE user_id=v_user AND kind='vip_purchase'
  AND idempotency_key='vip:' || p_key;
  IF FOUND THEN
    IF (v_existing->>'tier')::integer IS DISTINCT FROM p_tier THEN
      RAISE EXCEPTION 'Purchase idempotency payload mismatch';
    END IF;
    RETURN pg_catalog.jsonb_build_object(
      'status','replayed','tier',p_tier,'expires_at',v_existing->>'expires_at'
    );
  END IF;

  SELECT coin_price,duration_days INTO v_coins,v_days
  FROM public.normal_vip_catalog WHERE tier=p_tier;
  IF v_coins IS NULL THEN RAISE EXCEPTION 'VIP tier not available'; END IF;

  SELECT vip_level,vip_expires_at INTO v_level,v_expiry
  FROM public.profiles
  WHERE id=v_user AND status='active' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account unavailable'; END IF;

  UPDATE public.wallets SET coins=coins-v_coins
  WHERE user_id=v_user AND coins>=v_coins;
  IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient coins'; END IF;

  -- Same-tier renewals extend; upgrades start a fresh paid cycle.
  v_expiry := CASE
    WHEN v_level=p_tier AND v_expiry>pg_catalog.now()
      THEN v_expiry
    ELSE pg_catalog.now()
  END + pg_catalog.make_interval(days=>v_days);

  UPDATE public.profiles
  SET vip_level=p_tier,vip_expires_at=v_expiry,vip_last_claim=NULL
  WHERE id=v_user;

  INSERT INTO public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  VALUES(
    v_user,'vip_purchase',-v_coins,0,
    pg_catalog.jsonb_build_object(
      'tier',p_tier,'price',v_coins,'expires_at',v_expiry,
      'source','nimzo_verified_normal_vip'
    ),
    'vip:' || p_key
  );

  RETURN pg_catalog.jsonb_build_object(
    'status','ok','tier',p_tier,'cost',v_coins,'expires_at',v_expiry
  );
END;
$$;
REVOKE ALL ON FUNCTION public.purchase_normal_vip(integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purchase_normal_vip(integer,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.purchase_normal_vip(integer,text) TO authenticated;

-- Keep legacy activate_vip privileged; clients must not be able to grant tiers.
REVOKE ALL ON FUNCTION public.activate_vip(uuid,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.activate_vip(uuid,integer) FROM anon;
REVOKE ALL ON FUNCTION public.activate_vip(uuid,integer) FROM authenticated;

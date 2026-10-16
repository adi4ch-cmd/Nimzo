-- NIMZO gift economics: receiver earns 45% diamonds on EVERY settled gift,
-- including gifts sent to self.  No ledger records are rewritten or backfilled.
-- Settlement/idempotency/room authorization remain server-side.
DO $$
DECLARE
  func text;
  f regprocedure;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.send_gift(uuid,uuid,uuid,integer,text)'::regprocedure,
    'public.send_moment_gift(uuid,uuid,uuid,integer,text)'::regprocedure
  ] LOOP
    SELECT pg_get_functiondef(f::oid) INTO func;
    IF position('diamond_credit:=case when s=p_receiver then 0 else total*45/100 end;' IN func)=0
       OR position('if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;' IN func)=0 THEN
      RAISE EXCEPTION 'Existing gift settlement contract changed. Manual review required: %',f;
    END IF;
    func:=replace(func,
      'diamond_credit:=case when s=p_receiver then 0 else total*45/100 end;',
      'diamond_credit:=total*45/100;');
    func:=replace(func,
      'if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;',
      'update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver;');
    EXECUTE func;
  END LOOP;

  f:='nimzo_private.send_profile_gift(uuid,uuid,integer,text)'::regprocedure;
  SELECT pg_get_functiondef(f::oid) INTO func;
  IF position('p_receiver is null or p_receiver=s or p_gift is null' IN func)=0
     OR position('(select count(*) from public.wallets where user_id in(s,p_receiver))<>2' IN func)=0 THEN
    RAISE EXCEPTION 'Existing profile gift settlement contract changed. Manual review required';
  END IF;
  func:=replace(func,
    'p_receiver is null or p_receiver=s or p_gift is null',
    'p_receiver is null or p_gift is null');
  func:=replace(func,
    '(select count(*) from public.wallets where user_id in(s,p_receiver))<>2',
    '(select count(*) from public.wallets where user_id in(s,p_receiver))<>case when s=p_receiver then 1 else 2 end');
  -- Legacy function body ended with "end" without the final PL/pgSQL
  -- statement semicolon; normalize before recompiling its definition.
  func:=replace(func,'end $function
END $$;

-- Exchange one diamond for one coin. An idempotency key is mandatory,
-- and exchanges are serialized per account/key to prevent retry-double-credit.
CREATE OR REPLACE FUNCTION public.exchange_diamonds(p_amount bigint,p_key text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_user uuid:=auth.uid();
  prior jsonb;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_amount>9223372036854775807 THEN
    RAISE EXCEPTION 'invalid diamond exchange amount';
  END IF;
  IF nullif(trim(p_key),'') IS NULL OR length(p_key)>200 THEN
    RAISE EXCEPTION 'exchange idempotency key required';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('diamond_exchange:'||v_user::text||':'||p_key,0)
  );
  SELECT l.ref INTO prior FROM public.ledger l
    WHERE l.user_id=v_user AND l.kind='exchange' AND l.idempotency_key=p_key;
  IF FOUND THEN
    IF prior->>'amount' IS DISTINCT FROM p_amount::text THEN
      RAISE EXCEPTION 'exchange idempotency amount mismatch';
    END IF;
    RETURN;
  END IF;
  UPDATE public.wallets SET diamonds=diamonds-p_amount,coins=coins+p_amount
    WHERE user_id=v_user AND diamonds>=p_amount;
  IF NOT FOUND THEN RAISE EXCEPTION 'insufficient diamonds'; END IF;
  INSERT INTO public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  VALUES(v_user,'exchange',p_amount,-p_amount,
    jsonb_build_object('rate','1:1','amount',p_amount),p_key);
END;
$$;
REVOKE ALL ON FUNCTION public.exchange_diamonds(bigint,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.exchange_diamonds(bigint,text) TO authenticated;
,'end; $function
END $$;

-- Exchange one diamond for one coin. An idempotency key is mandatory,
-- and exchanges are serialized per account/key to prevent retry-double-credit.
CREATE OR REPLACE FUNCTION public.exchange_diamonds(p_amount bigint,p_key text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_user uuid:=auth.uid();
  prior jsonb;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_amount>9223372036854775807 THEN
    RAISE EXCEPTION 'invalid diamond exchange amount';
  END IF;
  IF nullif(trim(p_key),'') IS NULL OR length(p_key)>200 THEN
    RAISE EXCEPTION 'exchange idempotency key required';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('diamond_exchange:'||v_user::text||':'||p_key,0)
  );
  SELECT l.ref INTO prior FROM public.ledger l
    WHERE l.user_id=v_user AND l.kind='exchange' AND l.idempotency_key=p_key;
  IF FOUND THEN
    IF prior->>'amount' IS DISTINCT FROM p_amount::text THEN
      RAISE EXCEPTION 'exchange idempotency amount mismatch';
    END IF;
    RETURN;
  END IF;
  UPDATE public.wallets SET diamonds=diamonds-p_amount,coins=coins+p_amount
    WHERE user_id=v_user AND diamonds>=p_amount;
  IF NOT FOUND THEN RAISE EXCEPTION 'insufficient diamonds'; END IF;
  INSERT INTO public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  VALUES(v_user,'exchange',p_amount,-p_amount,
    jsonb_build_object('rate','1:1','amount',p_amount),p_key);
END;
$$;
REVOKE ALL ON FUNCTION public.exchange_diamonds(bigint,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.exchange_diamonds(bigint,text) TO authenticated;
);
  EXECUTE func;
END $$;

-- Exchange one diamond for one coin. An idempotency key is mandatory,
-- and exchanges are serialized per account/key to prevent retry-double-credit.
CREATE OR REPLACE FUNCTION public.exchange_diamonds(p_amount bigint,p_key text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
  v_user uuid:=auth.uid();
  prior jsonb;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  IF p_amount IS NULL OR p_amount<=0 OR p_amount>9223372036854775807 THEN
    RAISE EXCEPTION 'invalid diamond exchange amount';
  END IF;
  IF nullif(trim(p_key),'') IS NULL OR length(p_key)>200 THEN
    RAISE EXCEPTION 'exchange idempotency key required';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('diamond_exchange:'||v_user::text||':'||p_key,0)
  );
  SELECT l.ref INTO prior FROM public.ledger l
    WHERE l.user_id=v_user AND l.kind='exchange' AND l.idempotency_key=p_key;
  IF FOUND THEN
    IF prior->>'amount' IS DISTINCT FROM p_amount::text THEN
      RAISE EXCEPTION 'exchange idempotency amount mismatch';
    END IF;
    RETURN;
  END IF;
  UPDATE public.wallets SET diamonds=diamonds-p_amount,coins=coins+p_amount
    WHERE user_id=v_user AND diamonds>=p_amount;
  IF NOT FOUND THEN RAISE EXCEPTION 'insufficient diamonds'; END IF;
  INSERT INTO public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  VALUES(v_user,'exchange',p_amount,-p_amount,
    jsonb_build_object('rate','1:1','amount',p_amount),p_key);
END;
$$;
REVOKE ALL ON FUNCTION public.exchange_diamonds(bigint,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.exchange_diamonds(bigint,text) TO authenticated;

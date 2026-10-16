-- Keep the private schema inaccessible to clients. These four public facades
-- are the intentional authenticated API boundary, not general table access.
-- The delegated functions retain their existing ownership, consent, blocks,
-- active-account, wallet-lock and idempotency checks based on auth.uid().
CREATE OR REPLACE FUNCTION public.profile_stats(p_user uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$ BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  RETURN nimzo_private.profile_stats(p_user);
END $$;

CREATE OR REPLACE FUNCTION public.record_visit(p_profile uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$ BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  PERFORM nimzo_private.record_visit(p_profile);
END $$;

CREATE OR REPLACE FUNCTION public.respond_couple_request(p_request uuid,p_accept boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$ BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  PERFORM nimzo_private.respond_couple_request(p_request,p_accept);
END $$;

CREATE OR REPLACE FUNCTION public.send_profile_gift(p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$ BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='28000'; END IF;
  RETURN nimzo_private.send_profile_gift(p_receiver,p_gift,p_qty,p_key);
END $$;

REVOKE ALL ON FUNCTION public.profile_stats(uuid),public.record_visit(uuid),
  public.respond_couple_request(uuid,boolean),public.send_profile_gift(uuid,uuid,integer,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.profile_stats(uuid),public.record_visit(uuid),
  public.respond_couple_request(uuid,boolean),public.send_profile_gift(uuid,uuid,integer,text)
  TO authenticated;

-- Inner implementations are callable only through the guarded public facade.
REVOKE ALL ON FUNCTION nimzo_private.profile_stats(uuid),nimzo_private.record_visit(uuid),
  nimzo_private.respond_couple_request(uuid,boolean),nimzo_private.send_profile_gift(uuid,uuid,integer,text)
  FROM PUBLIC,anon,authenticated;

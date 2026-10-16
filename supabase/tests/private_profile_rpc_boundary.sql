-- Run inside a rollback transaction, including after deployment.
DO $$
DECLARE signature text;
BEGIN
  IF has_schema_privilege('authenticated','nimzo_private','USAGE')
    OR has_schema_privilege('anon','nimzo_private','USAGE') THEN
    RAISE EXCEPTION 'Private schema exposed to clients';
  END IF;
  FOREACH signature IN ARRAY ARRAY['profile_stats(uuid)','record_visit(uuid)',
    'respond_couple_request(uuid,boolean)','send_profile_gift(uuid,uuid,integer,text)'] LOOP
    IF has_function_privilege('anon','public.'||signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Anonymous public API access: %',signature;
    END IF;
    IF NOT has_function_privilege('authenticated','public.'||signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Authenticated API inaccessible: %',signature;
    END IF;
    IF has_function_privilege('authenticated','nimzo_private.'||signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Private implementation executable: %',signature;
    END IF;
  END LOOP;
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ BEGIN
  BEGIN PERFORM public.profile_stats(null); RAISE EXCEPTION 'Missing-session statistics allowed';
  EXCEPTION WHEN invalid_authorization_specification THEN NULL; END;
  BEGIN PERFORM public.record_visit(null); RAISE EXCEPTION 'Missing-session visit allowed';
  EXCEPTION WHEN invalid_authorization_specification THEN NULL; END;
  BEGIN PERFORM public.respond_couple_request(null,true); RAISE EXCEPTION 'Missing-session consent allowed';
  EXCEPTION WHEN invalid_authorization_specification THEN NULL; END;
  BEGIN PERFORM public.send_profile_gift(null,null,1,'unauthenticated'); RAISE EXCEPTION 'Missing-session gift allowed';
  EXCEPTION WHEN invalid_authorization_specification THEN NULL; END;
END $$;
RESET ROLE;

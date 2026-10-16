-- A concurrent production migration explicitly enabled profile self-gifting.
-- Its two-wallet assertion still rejected a self gift, which has one distinct
-- wallet. Patch only that assertion; preserve all other deployed logic.
DO $$
DECLARE definition text;
 old_check constant text := 'if (select count(*) from public.wallets where user_id in(s,p_receiver))<>2 then';
 new_check constant text := 'if (select count(*) from public.wallets where user_id in(s,p_receiver))<>(case when s=p_receiver then 1 else 2 end) then';
BEGIN
 definition:=pg_get_functiondef('nimzo_private.send_profile_gift(uuid,uuid,integer,text)'::regprocedure);
 IF position(new_check IN definition)>0 THEN RETURN; END IF;
 IF position(old_check IN definition)=0 OR position('p_receiver=s' IN definition)>0 THEN
  RAISE EXCEPTION 'Profile gift implementation changed; inspect before patching';
 END IF;
 EXECUTE replace(definition,old_check,new_check);
END $$;

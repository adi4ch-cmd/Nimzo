-- VIP/SVIP entrance effects require a fresh, server-authorized room join.
-- Reuse the existing immutable room entry event stream; never add a fake
-- client-side animation event or award membership in Flutter.
BEGIN;
CREATE OR REPLACE FUNCTION nimzo_private.phoenix_room_entry()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $f$
BEGIN
  INSERT INTO public.phoenix_room_entries(room_id,user_id,display_name,created_at)
  SELECT NEW.room_id,p.id,
    COALESCE(NULLIF(p.display_name,''),NULLIF(p.username,''),'NIMZO user'),
    COALESCE(NEW.joined_at,pg_catalog.clock_timestamp())
  FROM public.profiles p
  WHERE p.id=NEW.user_id AND p.status='active'
    AND (
      (p.vip_level BETWEEN 1 AND 10
       AND p.vip_expires_at>pg_catalog.clock_timestamp())
      OR
      (p.svip_level BETWEEN 1 AND 10 AND p.svip_cycle_start IS NOT NULL
       AND p.svip_cycle_start+interval '90 days'>pg_catalog.clock_timestamp())
    );
  RETURN NEW;
END;
$f$;
CREATE OR REPLACE FUNCTION public.phoenix_membership(p_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path=''
AS $f$
 SELECT pg_catalog.jsonb_build_object(
    'vip_level',CASE WHEN p.status='active'
      AND p.vip_expires_at>pg_catalog.now()
      THEN COALESCE(p.vip_level,0) ELSE 0 END,
    'vip_expires_at',p.vip_expires_at,
    'svip_level',CASE WHEN p.status='active' AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days'>pg_catalog.now()
      THEN COALESCE(p.svip_level,0) ELSE 0 END,
    'svip_expires_at',p.svip_cycle_start+interval '90 days',
    'server_now',pg_catalog.now())
 FROM public.profiles p
 WHERE p.id=p_user AND auth.uid() IS NOT NULL;
$f$;
NOTIFY pgrst,'reload schema';
COMMIT;
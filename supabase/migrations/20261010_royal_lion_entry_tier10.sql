-- NIMZO Royal Lion is a new VIP 10-only effect, not the old VIP 6 Phoenix.
-- Retain existing event table/permissions for compatibility; never replay history.
-- Server emits one row only on a genuine room_members INSERT with an eligible
-- active profile. No user-side INSERT permissions are added.
CREATE OR REPLACE FUNCTION nimzo_private.phoenix_room_entry()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
  INSERT INTO public.phoenix_room_entries(room_id,user_id,display_name,created_at)
  SELECT NEW.room_id,p.id,
    coalesce(nullif(p.display_name,''),nullif(p.username,''),'Nimzo user'),
    NEW.joined_at
  FROM public.profiles p
  WHERE p.id = NEW.user_id
    AND p.status = 'active'
    AND p.vip_level = 10
    AND p.vip_expires_at > pg_catalog.clock_timestamp();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION nimzo_private.phoenix_room_entry() FROM PUBLIC, anon, authenticated;
-- The trigger remains installed on room_members; function is trigger-only.

-- Harden private Gift activation/send: approved metadata alone is not enough.
-- An actual object must exist in the existing private Storage bucket.
BEGIN;
CREATE OR REPLACE FUNCTION nimzo_internal.private_dynamic_gift_ready(p_gift_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
SELECT EXISTS (
 SELECT 1 FROM public.nimzo_private_gift_media m
 JOIN storage.objects o
   ON o.bucket_id='nimzo-private-gifts'
  AND o.name=m.storage_path
 WHERE m.gift_id=p_gift_id AND m.approved
   AND o.metadata->>'mimetype'='video/mp4'
);
$$;
REVOKE ALL ON FUNCTION nimzo_internal.private_dynamic_gift_ready(uuid)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION nimzo_internal.require_gift_media_on_activation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.active AND NEW.requires_approved_media
     AND NOT EXISTS (
       SELECT 1 FROM public.gift_animation_media m
       WHERE m.gift_id=NEW.id AND m.approved
     )
     AND NOT nimzo_internal.private_dynamic_gift_ready(NEW.id)
  THEN RAISE EXCEPTION 'Cannot activate gift without approved available media'
       USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION nimzo_internal.reject_unplayable_settled_gift()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.gifts g
    WHERE g.id=NEW.gift_id AND g.requires_approved_media
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.gift_animation_media m
    WHERE m.gift_id=NEW.gift_id AND m.approved
  )
  AND NOT nimzo_internal.private_dynamic_gift_ready(NEW.gift_id)
  THEN
    RAISE EXCEPTION 'Gift animation unavailable; no coins charged'
      USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END;
$$;
COMMIT;
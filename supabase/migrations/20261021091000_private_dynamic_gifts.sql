-- Additive dynamic private gift media. No user data, ledger, balances,
-- older gift-media Edge Function, prices or approved rows are changed.
BEGIN;
SET LOCAL lock_timeout='8s';
CREATE TABLE IF NOT EXISTS public.nimzo_private_gift_media (
  gift_id uuid PRIMARY KEY REFERENCES public.gifts(id) ON DELETE RESTRICT,
  storage_path text NOT NULL UNIQUE CHECK (
    storage_path ~ '^dynamic/[a-zA-Z0-9_/-]{5,200}/[0-9a-f]{64}\\.mp4$'
    AND storage_path !~ '\\.\\.'
  ),
  sha256 text NOT NULL CHECK(sha256 ~ '^[0-9a-f]{64}$'),
  media_kind text NOT NULL CHECK(media_kind IN ('vap','mp4')),
  duration_ms integer NOT NULL CHECK(duration_ms BETWEEN 1000 AND 30000),
  approved boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.nimzo_private_gift_media ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nimzo_private_gift_media FROM PUBLIC, anon, authenticated;
-- No client SELECT policy. This table stores hidden private object paths.
DROP TRIGGER IF EXISTS nimzo_revision_private_gift_media
  ON public.nimzo_private_gift_media;
CREATE TRIGGER nimzo_revision_private_gift_media
AFTER INSERT OR UPDATE OR DELETE ON public.nimzo_private_gift_media
FOR EACH STATEMENT
EXECUTE FUNCTION nimzo_internal.bump_content_revision('gifts');

CREATE OR REPLACE FUNCTION nimzo_internal.require_gift_media_on_activation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.active AND NEW.requires_approved_media
     AND NOT EXISTS (
       SELECT 1 FROM public.gift_animation_media m
       WHERE m.gift_id=NEW.id AND m.approved
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.nimzo_private_gift_media p
       WHERE p.gift_id=NEW.id AND p.approved
     )
  THEN
    RAISE EXCEPTION 'Cannot activate gift without approved playback media'
      USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION nimzo_internal.require_gift_media_on_activation()
 FROM PUBLIC,anon,authenticated;

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
  AND NOT EXISTS (
    SELECT 1 FROM public.nimzo_private_gift_media p
    WHERE p.gift_id=NEW.gift_id AND p.approved
  ) THEN
    RAISE EXCEPTION 'Gift animation unavailable; no coins charged'
       USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION nimzo_internal.reject_unplayable_settled_gift()
 FROM PUBLIC,anon,authenticated;
COMMIT;
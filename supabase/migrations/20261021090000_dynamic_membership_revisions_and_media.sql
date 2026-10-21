-- Dynamic membership catalogs and approved artwork; existing prices, rewards,
-- balances, historic membership state and assets remain UNCHANGED.
BEGIN;
SET LOCAL lock_timeout = '8s';

ALTER TABLE public.nimzo_content_revisions
  DROP CONSTRAINT IF EXISTS nimzo_content_revisions_channel_check;
ALTER TABLE public.nimzo_content_revisions
  ADD CONSTRAINT nimzo_content_revisions_channel_check
  CHECK (channel IN ('gifts','store','banners','games','settings','membership'));

INSERT INTO public.nimzo_content_revisions(channel,revision)
VALUES ('membership',1)
ON CONFLICT (channel) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.nimzo_membership_media (
  kind text NOT NULL CHECK (kind IN ('vip','svip')),
  tier smallint NOT NULL CHECK (tier BETWEEN 1 AND 10),
  slot text NOT NULL CHECK (slot IN (
    'hero','badge','avatar_frame','entry','nameplate','chat_bubble',
    'mic_wave','room_background','privilege','expiration'
  )),
  asset_url text NOT NULL CHECK (
    asset_url ~ '^https://[^[:space:]]+$' AND length(asset_url) <= 2048
  ),
  media_kind text NOT NULL CHECK (media_kind IN ('image','svga','vap')),
  thumbnail_url text CHECK (
    thumbnail_url IS NULL OR
    (thumbnail_url ~ '^https://[^[:space:]]+$' AND length(thumbnail_url) <= 2048)
  ),
  sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  approved boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(kind,tier,slot),
  CONSTRAINT nimzo_membership_entry_media_check
    CHECK (slot <> 'entry' OR media_kind IN ('svga','vap')),
  CONSTRAINT nimzo_membership_nonentry_image_kind
    CHECK (slot = 'entry' OR media_kind IN ('image','svga'))
);
ALTER TABLE public.nimzo_membership_media ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nimzo_membership_media FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.nimzo_membership_media TO authenticated;

DROP POLICY IF EXISTS nimzo_membership_approved_media_read
  ON public.nimzo_membership_media;
CREATE POLICY nimzo_membership_approved_media_read
  ON public.nimzo_membership_media
  FOR SELECT TO authenticated
  USING (approved);

DROP TRIGGER IF EXISTS nimzo_revision_membership_media
  ON public.nimzo_membership_media;
CREATE TRIGGER nimzo_revision_membership_media
  AFTER INSERT OR UPDATE OR DELETE ON public.nimzo_membership_media
  FOR EACH STATEMENT EXECUTE FUNCTION nimzo_internal.bump_content_revision('membership');

DROP TRIGGER IF EXISTS nimzo_revision_vip_catalog ON public.normal_vip_catalog;
CREATE TRIGGER nimzo_revision_vip_catalog
  AFTER INSERT OR UPDATE OR DELETE ON public.normal_vip_catalog
  FOR EACH STATEMENT EXECUTE FUNCTION nimzo_internal.bump_content_revision('membership');

DROP TRIGGER IF EXISTS nimzo_revision_svip_thresholds ON public.svip_thresholds;
CREATE TRIGGER nimzo_revision_svip_thresholds
  AFTER INSERT OR UPDATE OR DELETE ON public.svip_thresholds
  FOR EACH STATEMENT EXECUTE FUNCTION nimzo_internal.bump_content_revision('membership');

DROP TRIGGER IF EXISTS nimzo_revision_vip_rewards ON public.vip_daily_rewards;
CREATE TRIGGER nimzo_revision_vip_rewards
  AFTER INSERT OR UPDATE OR DELETE ON public.vip_daily_rewards
  FOR EACH STATEMENT EXECUTE FUNCTION nimzo_internal.bump_content_revision('membership');

DROP TRIGGER IF EXISTS nimzo_revision_svip_rewards ON public.svip_friday_rewards;
CREATE TRIGGER nimzo_revision_svip_rewards
  AFTER INSERT OR UPDATE OR DELETE ON public.svip_friday_rewards
  FOR EACH STATEMENT EXECUTE FUNCTION nimzo_internal.bump_content_revision('membership');

-- No user IDs or private entitlement details are broadcast: only a monotonically
-- increasing revision changes for effective membership grant/expiry updates.
CREATE OR REPLACE FUNCTION nimzo_internal.member_status_revision()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '' AS $$
BEGIN
  IF (OLD.vip_level,OLD.vip_expires_at,OLD.vip_last_claim,
      OLD.svip_level,OLD.svip_cycle_start,OLD.svip_cycle_cents,OLD.svip_last_claim)
     IS DISTINCT FROM
     (NEW.vip_level,NEW.vip_expires_at,NEW.vip_last_claim,
      NEW.svip_level,NEW.svip_cycle_start,NEW.svip_cycle_cents,NEW.svip_last_claim)
  THEN
    INSERT INTO public.nimzo_content_revisions(channel,revision,updated_at)
    VALUES ('membership',1,now())
    ON CONFLICT (channel) DO UPDATE
      SET revision=public.nimzo_content_revisions.revision+1, updated_at=now();
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION nimzo_internal.member_status_revision()
  FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS nimzo_membership_profile_revision ON public.profiles;
CREATE TRIGGER nimzo_membership_profile_revision
  AFTER UPDATE OF vip_level,vip_expires_at,vip_last_claim,
                  svip_level,svip_cycle_start,svip_cycle_cents,svip_last_claim
  ON public.profiles FOR EACH ROW
  EXECUTE FUNCTION nimzo_internal.member_status_revision();
COMMIT;
-- NIMZO live-data recovery only: six previously equipped, still-owned cosmetics.
-- Safe no-op for fresh environments, other owners, or a nonempty equipped state.
-- Never changes wallet, inventory ownership, history, or catalog prices.
CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS nimzo_private.equipped_cleanup_recovery_log_20261021(
 item_id text PRIMARY KEY,user_id uuid NOT NULL,category text NOT NULL,
 recovered_at timestamptz NOT NULL DEFAULT now());
REVOKE ALL ON nimzo_private.equipped_cleanup_recovery_log_20261021 FROM PUBLIC,anon,authenticated;
ALTER TABLE nimzo_private.equipped_cleanup_recovery_log_20261021 ENABLE ROW LEVEL SECURITY;
DO $restore$
DECLARE ids text[]:=ARRAY['nimzo-media-id-gold','nimzo-media-frame-family',
'nimzo-media-profile-blue','nimzo-media-badge-millionaire',
'nimzo-media-entrance-3','nimzo-media-mic-cp_mic_seat_anim'];
BEGIN
 IF (SELECT count(*) FROM public.nimzo_cosmetic_equipped)<>0 THEN RETURN; END IF;
 IF (SELECT count(*) FROM public.nimzo_cosmetic_ownership WHERE item_id=ANY(ids))<>6 THEN RETURN; END IF;
 IF (SELECT count(DISTINCT user_id) FROM public.nimzo_cosmetic_ownership WHERE item_id=ANY(ids))<>1 THEN RETURN; END IF;
 INSERT INTO public.nimzo_cosmetic_equipped(user_id,category,item_id,equipped_at)
 SELECT o.user_id,c.category,o.item_id,now()
 FROM public.nimzo_cosmetic_ownership o JOIN public.nimzo_cosmetic_catalog c ON c.id=o.item_id
 WHERE o.item_id=ANY(ids) ON CONFLICT (user_id,category) DO NOTHING;
 INSERT INTO nimzo_private.equipped_cleanup_recovery_log_20261021(item_id,user_id,category)
 SELECT o.item_id,o.user_id,c.category FROM public.nimzo_cosmetic_ownership o
 JOIN public.nimzo_cosmetic_catalog c ON c.id=o.item_id WHERE o.item_id=ANY(ids)
 ON CONFLICT DO NOTHING;
END $restore$;

-- Applied to NIMZO live Supabase 2026-10-21.
-- Archive candidates only. Gift history/ledger is sacred; no gift deletion is done.
CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS nimzo_private.retired_unused_gifts_20261021 AS
SELECT g.* FROM public.gifts g
WHERE g.active = false
AND NOT EXISTS (SELECT 1 FROM public.gift_events e WHERE e.gift_id=g.id)
AND NOT EXISTS (SELECT 1 FROM public.gift_animation_events a WHERE a.gift_id=g.id);
REVOKE ALL ON nimzo_private.retired_unused_gifts_20261021 FROM PUBLIC,anon,authenticated;
ALTER TABLE nimzo_private.retired_unused_gifts_20261021 ENABLE ROW LEVEL SECURITY;

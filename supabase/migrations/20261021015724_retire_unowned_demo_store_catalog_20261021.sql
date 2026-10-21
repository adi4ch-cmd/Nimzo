-- Applied to NIMZO live Supabase 2026-10-21. Remove 41 unowned mock Store variants.
-- Keep any item owned/equipped by a user; never alter wallets, ledger, or ownership.
CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS nimzo_private.retired_store_mock_catalog_20261021 AS
SELECT c.* FROM public.nimzo_cosmetic_catalog c
WHERE c.id LIKE 'nimzo-original-%' AND c.coin_price=0
AND NOT EXISTS (SELECT 1 FROM public.nimzo_cosmetic_ownership o WHERE o.item_id=c.id)
AND NOT EXISTS (SELECT 1 FROM public.nimzo_cosmetic_equipped e WHERE e.item_id=c.id);
REVOKE ALL ON nimzo_private.retired_store_mock_catalog_20261021 FROM PUBLIC,anon,authenticated;
ALTER TABLE nimzo_private.retired_store_mock_catalog_20261021 ENABLE ROW LEVEL SECURITY;
DO $check$ DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM nimzo_private.retired_store_mock_catalog_20261021;
 IF n <> 41 THEN RAISE EXCEPTION 'Unexpected retired Store mock count: %',n; END IF;
END $check$;
DELETE FROM public.nimzo_cosmetic_catalog c
WHERE c.id IN (SELECT b.id FROM nimzo_private.retired_store_mock_catalog_20261021 b)
AND NOT EXISTS (SELECT 1 FROM public.nimzo_cosmetic_ownership o WHERE o.item_id=c.id)
AND NOT EXISTS (SELECT 1 FROM public.nimzo_cosmetic_equipped e WHERE e.item_id=c.id);
NOTIFY pgrst,'reload schema';

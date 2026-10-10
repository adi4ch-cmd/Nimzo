-- RETIRED LEGACY CLEANUP: NIMZO v1.0.17 ships twenty tested gift icons
-- and matching built-in motion effects. The earlier draft would deactivate
-- fourteen approved products and DELETE IDs, breaking the final catalog.
-- Preserve this migration path for deployment order, but never remove or
-- deactivate gifts here. Historical gift_events and wallet ledgers are immutable.
--
-- The preceding final 20-gift activation verifies old six IDs/prices and all
-- fourteen custom SVG paths. This guard catches out-of-order deployments
-- without changing any live user or financial data.
DO $$
DECLARE v_total integer; v_active integer;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE active)
    INTO v_total, v_active FROM public.gifts;
  IF v_total <> 20 OR v_active <> 20 THEN
    RAISE EXCEPTION
      'Expected complete active NIMZO twenty-gift catalog, found % total / % active. Refusing retired destructive cleanup.',
      v_total, v_active;
  END IF;
END $$;

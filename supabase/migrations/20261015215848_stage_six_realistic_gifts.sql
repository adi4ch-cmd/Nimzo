-- User authorized 2026-10-15: 500,000 coins EACH for these six NEW gifts.
-- STAGING ONLY. No media or art has passed acceptance; never activate here.
-- No existing gift ID, price, artwork, activation, user, wallet or ledger update.
DO $$
DECLARE planned record; existing public.gifts%rowtype;
BEGIN
  -- Serialize the small catalog change, including duplicate-name checks.
  LOCK TABLE public.gifts IN SHARE ROW EXCLUSIVE MODE;
  FOR planned IN SELECT * FROM (VALUES
    ('8b4dfa2b-192e-4c90-89dd-8d9598d142c8'::uuid,'Red Luxury Supercar'),
    ('bf064182-3921-4e8b-aff1-7fca143470a8'::uuid,'Black Luxury Supercar'),
    ('90d1ffac-62a4-4cd7-b8a3-ef298e4207da'::uuid,'Gold Luxury Supercar'),
    ('d63cfcf1-8b5f-4852-af7b-8ffbd6bb348e'::uuid,'Blue Luxury Supercar'),
    ('97a5410c-4e42-411d-b291-fb67186a3bf7'::uuid,'Royal Lion'),
    ('f7720b54-9eef-4186-9d37-3db4796a2b67'::uuid,'Royal Tiger')
  ) AS gifts(id,name) LOOP
    SELECT * INTO existing FROM public.gifts WHERE id=planned.id;
    IF FOUND THEN
      IF existing.name IS DISTINCT FROM planned.name THEN
        RAISE EXCEPTION 'Six-gift identity conflict for %',planned.id;
      END IF;
      IF existing.coin_price IS DISTINCT FROM 500000::bigint THEN
        RAISE EXCEPTION 'Six-gift price conflict for %; existing price preserved',planned.id;
      END IF;
    END IF;
    IF EXISTS(SELECT 1 FROM public.gifts g
        WHERE lower(btrim(g.name))=lower(planned.name) AND g.id<>planned.id) THEN
      RAISE EXCEPTION 'Six-gift name conflict for %',planned.name;
    END IF;
    INSERT INTO public.gifts(id,name,category,coin_price,asset_path,min_vip,min_svip,active)
    VALUES(planned.id,planned.name,'premium',500000,NULL,0,0,false)
    ON CONFLICT(id) DO NOTHING;
  END LOOP;
END $$;

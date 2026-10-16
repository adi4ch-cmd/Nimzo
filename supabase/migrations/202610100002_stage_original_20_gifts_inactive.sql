-- Draft 20-gift collection: only NEW products are staged inactive.
-- Never expose 14 unbundled icons/animations to old 1.0.16 installations.
-- Existing settled gift UUIDs, six active prices, and wallets stay unchanged.
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.gifts
  WHERE active AND lower(trim(name)) IN (
    'rose','heart','crown','diamond','rocket','sports car'
  );
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'Expected the six stable live free gifts';
  END IF;
  IF EXISTS(SELECT 1 FROM public.gifts
    GROUP BY lower(trim(name)) HAVING count(*)>1) THEN
    RAISE EXCEPTION 'Duplicated catalog names, abort staged gift import';
  END IF;
END $$;

WITH proposed(name,category,coin_price,art_path) AS (
  VALUES
    ('Kiss','classic',2500::bigint,'assets/nimzo_custom_gifts/kiss.svg'),
    ('Coffee','classic',5000::bigint,'assets/nimzo_custom_gifts/coffee.svg'),
    ('Cat','classic',7500::bigint,'assets/nimzo_custom_gifts/cat.svg'),
    ('Birthday Cake','classic',12500::bigint,'assets/nimzo_custom_gifts/birthday_cake.svg'),
    ('Teddy Bear','classic',15000::bigint,'assets/nimzo_custom_gifts/teddy_bear.svg'),
    ('Gift Box','classic',20000::bigint,'assets/nimzo_custom_gifts/gift_box.svg'),
    ('Panda','classic',30000::bigint,'assets/nimzo_custom_gifts/panda.svg'),
    ('Diamond Ring','premium',75000::bigint,'assets/nimzo_custom_gifts/diamond_ring.svg'),
    ('Private Jet','premium',500000::bigint,'assets/nimzo_custom_gifts/private_jet.svg'),
    ('Phoenix','svip',5000000::bigint,'assets/nimzo_custom_gifts/phoenix.svg')
)
INSERT INTO public.gifts(name,category,coin_price,asset_path,active)
SELECT p.name,p.category,p.coin_price,p.art_path,false
FROM proposed p
WHERE NOT EXISTS (
  SELECT 1 FROM public.gifts g
  WHERE lower(trim(g.name))=lower(trim(p.name))
);

-- Four historic gift IDs stay unchanged, remain hidden on old installs,
-- and gain their distinct newly drawn NIMZO artwork only for future versions.
UPDATE public.gifts
SET asset_path=CASE lower(trim(name))
  WHEN 'golden palace' THEN 'assets/nimzo_custom_gifts/golden_palace.svg'
  WHEN 'luxury yacht' THEN 'assets/nimzo_custom_gifts/luxury_yacht.svg'
  WHEN 'dragon' THEN 'assets/nimzo_custom_gifts/dragon.svg'
  WHEN 'golden dragon' THEN 'assets/nimzo_custom_gifts/golden_dragon.svg'
END
WHERE lower(trim(name)) IN ('golden palace','luxury yacht','dragon','golden dragon')
  AND active=false;

DO $$
DECLARE v_rows int; v_active int;
BEGIN
  SELECT count(*) INTO v_rows FROM public.gifts;
  SELECT count(*) INTO v_active FROM public.gifts WHERE active;
  IF v_rows<>20 OR v_active<>6 THEN
    RAISE EXCEPTION 'Staged migration must leave 20 catalog rows and exactly 6 live gifts (got %, %)',v_rows,v_active;
  END IF;
END $$;

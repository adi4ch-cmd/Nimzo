-- FINAL ACTIVATION ONLY after full gift/VIP regression and final Android APK
-- asset verification. Do not apply while older 1.0.16 clients are still being
-- used for gift acceptance tests. Prices are those staged on 2026-10-10;
-- six original IDs, existing financial history and wallet data never change.
DO $$
DECLARE v_matched integer; v_good_old integer;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('nimzo_final_20_gifts',0));
  SELECT count(*) INTO v_matched FROM public.gifts;
  IF v_matched != 20 THEN
    RAISE EXCEPTION 'Need exactly 20 staged gifts, found %',v_matched;
  END IF;

  SELECT count(*) INTO v_good_old FROM public.gifts
    WHERE active
    AND (id,name,coin_price) IN (
      ('eb336fe8-8538-4f37-aa4d-9fac97ab4dfb'::uuid,'Rose',500),
      ('c4ae46dd-8ff1-49ae-bcfb-cf5f1885e330'::uuid,'Heart',1000),
      ('2aa6c5cf-1b4c-423b-a3c3-bfbb6f4ea037'::uuid,'Crown',10000),
      ('bda8bde4-6a1e-4c79-8998-2dfb866bd0c1'::uuid,'Diamond',25000),
      ('99faac6c-933c-4c08-8026-08c39227751e'::uuid,'Rocket',50000),
      ('35e4c570-cb02-4466-ae86-d670b3fb05ab'::uuid,'Sports Car',100000)
    );
  IF v_good_old <> 6 OR
     (SELECT count(*) FROM public.gifts WHERE active) <> 6 THEN
    RAISE EXCEPTION 'Six stable original gifts unexpectedly changed; cancel activation';
  END IF;

  WITH planned(name,price,path) AS (
    VALUES
      ('Kiss',2500::bigint,'kiss'),
      ('Coffee',5000::bigint,'coffee'),
      ('Cat',7500::bigint,'cat'),
      ('Birthday Cake',12500::bigint,'birthday_cake'),
      ('Teddy Bear',15000::bigint,'teddy_bear'),
      ('Gift Box',20000::bigint,'gift_box'),
      ('Panda',30000::bigint,'panda'),
      ('Diamond Ring',75000::bigint,'diamond_ring'),
      ('Luxury Yacht',250000::bigint,'luxury_yacht'),
      ('Private Jet',500000::bigint,'private_jet'),
      ('Dragon',1000000::bigint,'dragon'),
      ('Golden Palace',1000000::bigint,'golden_palace'),
      ('Golden Dragon',5000000::bigint,'golden_dragon'),
      ('Phoenix',5000000::bigint,'phoenix')
  )
  SELECT count(*) INTO v_matched
  FROM public.gifts g JOIN planned p ON g.name=p.name
  WHERE g.coin_price=p.price
    AND g.asset_path='assets/nimzo_custom_gifts/'||p.path||'.svg'
    AND g.active=false;
  IF v_matched <> 14 THEN
    RAISE EXCEPTION 'Fourteen gifts do not match approved staged icon/price mapping: %',v_matched;
  END IF;

  UPDATE public.gifts
  SET active=true WHERE active=false;
  IF (SELECT count(*) FROM public.gifts WHERE active) <> 20 THEN
    RAISE EXCEPTION 'Final activation failed to produce exactly 20 available gifts';
  END IF;
END $$;

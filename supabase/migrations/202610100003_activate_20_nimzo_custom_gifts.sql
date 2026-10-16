-- Final NIMZO twenty-gift activation. Safe to replay in an already-active
-- production database; no settled gift IDs, prices, wallets, or ledger entries
-- may be changed. A fresh staged database must still start with exactly six
-- original live gifts and fourteen inactive NIMZO SVG gifts.
-- Production had already activated all twenty gifts before this migration was
-- recorded. Verify exact identities and artwork rather than failing/replacing.
DO $$
DECLARE v_matched integer; v_good_old integer; v_active integer;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo_final_20_gifts',0));

  SELECT count(*) INTO v_matched FROM public.gifts;
  IF v_matched != 20 THEN
    RAISE EXCEPTION 'Need exactly 20 staged gifts, found %', v_matched;
  END IF;

  SELECT count(*) INTO v_good_old FROM public.gifts
    WHERE active AND (id,name,coin_price) IN (
      ('eb336fe8-8538-4f37-aa4d-9fac97ab4dfb'::uuid,'Rose',500),
      ('c4ae46dd-8ff1-49ae-bcfb-cf5f1885e330'::uuid,'Heart',1000),
      ('2aa6c5cf-1b4c-423b-a3c3-bfbb6f4ea037'::uuid,'Crown',10000),
      ('bda8bde4-6a1e-4c79-8998-2dfb866bd0c1'::uuid,'Diamond',25000),
      ('99faac6c-933c-4c08-8026-08c39227751e'::uuid,'Rocket',50000),
      ('35e4c570-cb02-4466-ae86-d670b3fb05ab'::uuid,'Sports Car',100000)
    );
  SELECT count(*) INTO v_active FROM public.gifts WHERE active;
  IF v_good_old <> 6 OR v_active NOT IN (6,20) THEN
    RAISE EXCEPTION 'Original gift identities or activation state changed (original %, active %)',v_good_old,v_active;
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
    AND g.active=(v_active=20);
  IF v_matched <> 14 THEN
    RAISE EXCEPTION 'Fourteen gift icons/prices/states do not match approved catalog: %',v_matched;
  END IF;

  -- Activate ONLY the preverified fourteen staged rows on a fresh install.
  -- Live production with all twenty active performs no UPDATE at all.
  IF v_active=6 THEN
    UPDATE public.gifts SET active=true WHERE NOT active;
  END IF;
  IF (SELECT count(*) FROM public.gifts WHERE active)<>20 THEN
    RAISE EXCEPTION 'Final catalog requires exactly twenty active gifts';
  END IF;
END $$;

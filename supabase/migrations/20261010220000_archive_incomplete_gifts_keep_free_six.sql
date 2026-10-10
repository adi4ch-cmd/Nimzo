-- Only six genuinely paired free assets are offered for NEW gifting.
-- Old gift transactions/ledgers and existing accounts remain readable.
-- Never cascade-delete financial history to remove an incomplete gift.
-- Five unused gift IDs can be permanently removed; referenced gifts are deactivated.
DO $$
DECLARE
  v_keep uuid[] := ARRAY[
    'eb336fe8-8538-4f37-aa4d-9fac97ab4dfb'::uuid, -- Rose
    'c4ae46dd-8ff1-49ae-bcfb-cf5f1885e330'::uuid, -- Heart
    '2aa6c5cf-1b4c-423b-a3c3-bfbb6f4ea037'::uuid, -- Crown
    'bda8bde4-6a1e-4c79-8998-2dfb866bd0c1'::uuid, -- Diamond
    '99faac6c-933c-4c08-8026-08c39227751e'::uuid, -- Rocket
    '35e4c570-cb02-4466-ae86-d670b3fb05ab'::uuid  -- Sports Car
  ];
  v_valid int;
BEGIN
  SELECT count(*) INTO v_valid
  FROM public.gifts
  WHERE (id, lower(trim(name)), coin_price) IN (
    ('eb336fe8-8538-4f37-aa4d-9fac97ab4dfb'::uuid, 'rose', 500),
    ('c4ae46dd-8ff1-49ae-bcfb-cf5f1885e330'::uuid, 'heart', 1000),
    ('2aa6c5cf-1b4c-423b-a3c3-bfbb6f4ea037'::uuid, 'crown', 10000),
    ('bda8bde4-6a1e-4c79-8998-2dfb866bd0c1'::uuid, 'diamond', 25000),
    ('99faac6c-933c-4c08-8026-08c39227751e'::uuid, 'rocket', 50000),
    ('35e4c570-cb02-4466-ae86-d670b3fb05ab'::uuid, 'sports car', 100000)
  );
  IF v_valid != 6 THEN
    RAISE EXCEPTION 'Free gift catalog changed; refusing unsafe deletion';
  END IF;
  UPDATE public.gifts
    SET active = (id = ANY(v_keep))
    WHERE active IS DISTINCT FROM (id = ANY(v_keep));
  -- Five never-used incomplete gifts can be physically removed without
  -- destroying gift_event rows, trusted animation events or any wallet ledger.
  -- The other four incomplete gifts have settlements, so they stay inactive.
  DELETE FROM public.gifts g
  WHERE g.id IN (
    '7b73f7e7-ed4a-4c44-8873-54bd9e0d2659'::uuid, -- Coffee
    'cd7f0f74-003d-476b-be50-f7aed78ad5b9'::uuid, -- Kiss
    '75eb2f0f-cdbe-4f41-a8a3-aee3d655e7c0'::uuid, -- Private Jet
    'ce25005c-bb88-4e99-9891-e3d89e25e027'::uuid, -- Royal Dragon
    'b6fe7c14-ba89-4dec-9517-65660ef1c4a3'::uuid  -- Phoenix
  )
    AND NOT EXISTS (SELECT 1 FROM public.gift_events e WHERE e.gift_id=g.id)
    AND NOT EXISTS (SELECT 1 FROM public.gift_animation_events a WHERE a.gift_id=g.id)
    AND NOT EXISTS (SELECT 1 FROM public.gift_animation_media m WHERE m.gift_id=g.id)
    AND NOT EXISTS (SELECT 1 FROM public.ledger l WHERE l.ref->>'gift'=g.id::text);
  IF EXISTS (SELECT 1 FROM public.gifts WHERE id IN (
    '7b73f7e7-ed4a-4c44-8873-54bd9e0d2659'::uuid,
    'cd7f0f74-003d-476b-be50-f7aed78ad5b9'::uuid,
    '75eb2f0f-cdbe-4f41-a8a3-aee3d655e7c0'::uuid,
    'ce25005c-bb88-4e99-9891-e3d89e25e027'::uuid,
    'b6fe7c14-ba89-4dec-9517-65660ef1c4a3'::uuid
  )) THEN
    RAISE EXCEPTION 'A legacy gift gained references; aborting incomplete gift cleanup';
  END IF;
  IF (SELECT count(*) FROM public.gifts WHERE active) != 6 THEN
    RAISE EXCEPTION 'Expected exactly six active free gifts';
  END IF;
END $$;

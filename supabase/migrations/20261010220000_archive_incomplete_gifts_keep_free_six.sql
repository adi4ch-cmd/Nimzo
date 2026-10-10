-- Only six genuinely paired free assets are offered for NEW gifting.
-- Old gift transactions/ledgers and existing accounts remain readable.
-- Never cascade-delete financial history to remove an incomplete gift.
-- This is intentionally reversible (active flag), not destructive hard deletion.
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
  IF (SELECT count(*) FROM public.gifts WHERE active) != 6 THEN
    RAISE EXCEPTION 'Expected exactly six active free gifts';
  END IF;
END $$;

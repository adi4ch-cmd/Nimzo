-- Store only exact, bundled NIMZO artwork for specific priced gifts.
-- This never changes gift IDs, coin prices, ownership or completed ledgers.
-- Unmatched gifts retain their independent, named NIMZO SVG icon.
BEGIN;
UPDATE public.gifts
SET asset_path= CASE name
  WHEN 'Rose' THEN 'assets/reference/gift/1.jpg'
  WHEN 'Heart' THEN 'assets/reference/gift/2.jpg'
  WHEN 'Gift Box' THEN 'assets/reference/gift/3.jpg'
  WHEN 'Dragon' THEN 'assets/reference/gift/8.jpg'
  WHEN 'Crown' THEN 'assets/reference/gift/9.jpg'
  WHEN 'Diamond' THEN 'assets/reference/gift/7.jpg'
  WHEN 'Rocket' THEN 'assets/reference/gift/4.jpg'
  WHEN 'Sports Car' THEN 'assets/gifts/free/sports_car.png'
  ELSE asset_path END
WHERE name IN ('Rose','Heart','Gift Box','Dragon','Crown',
  'Diamond','Rocket','Sports Car') AND active = TRUE;
COMMIT;
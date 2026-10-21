-- First 3 genuinely published, original, full image Store cosmetics.
-- All binary bytes independently fetched over HTTPS from immutable Git commit,
-- SHA256-matched, structurally verified in Actions run 39566655294.
-- Free collect only; no change to wallets, ownership or old catalog items.
BEGIN;
INSERT INTO public.nimzo_cosmetic_catalog
(id,category,name,variant,coin_price,active)
VALUES
('nimzo-orig-id-ribbon-20261021','ID Frame','Original ID Ribbon',0,0,true),
('nimzo-orig-profile-royal-20261021','Profile Card','Royal Identity Panel',1,0,true),
('nimzo-orig-id-banner-20261021','ID Frame','Original ID Banner',2,0,true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.nimzo_cosmetic_media
(item_id,thumbnail_url,asset_url,media_kind,approved)
VALUES
('nimzo-orig-id-ribbon-20261021','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/942fbf97e1778d1cdb32b91716590219193102d6/nimzo/assets/willchill_premium/store/bg_chat_id_card.png','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/942fbf97e1778d1cdb32b91716590219193102d6/nimzo/assets/willchill_premium/store/bg_chat_id_card.png','image',true),
('nimzo-orig-profile-royal-20261021','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/942fbf97e1778d1cdb32b91716590219193102d6/nimzo/assets/willchill_premium/store/icon_char_id_card_id_bg.png','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/942fbf97e1778d1cdb32b91716590219193102d6/nimzo/assets/willchill_premium/store/icon_char_id_card_id_bg.png','image',true),
('nimzo-orig-id-banner-20261021','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/942fbf97e1778d1cdb32b91716590219193102d6/nimzo/assets/willchill_premium/store/icon_char_id_card_title_bg.png','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/942fbf97e1778d1cdb32b91716590219193102d6/nimzo/assets/willchill_premium/store/icon_char_id_card_title_bg.png','image',true)
ON CONFLICT (item_id) DO NOTHING;
COMMIT;

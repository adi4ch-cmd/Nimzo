-- Live original Tana full-resolution room backdrops from licensed APK assets.
-- Original entire WebP canvases (1125x2437,1125x2646), SHA256 verified and
-- downloaded byte-for-byte from immutable commit by Actions 39567447009.
-- Free preview/collect/equip; existing balances and users not touched.
BEGIN;
INSERT INTO public.nimzo_cosmetic_catalog(id,category,name,variant,coin_price,active)
VALUES
('nimzo-apk-theme-love-20261021','Party Theme','Love Room Theme',3,0,true),
('nimzo-apk-theme-supreme-20261021','Party Theme','Supreme Room Theme',4,0,true)
ON CONFLICT(id) DO NOTHING;

INSERT INTO public.nimzo_cosmetic_media
(item_id,thumbnail_url,asset_url,media_kind,approved)
VALUES
('nimzo-apk-theme-love-20261021','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/3042cfa7d47238c935e53ec9972dc1f4439738b9/nimzo/assets/licensed_tana_vani/tana/ic_room_theme_love.webp','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/3042cfa7d47238c935e53ec9972dc1f4439738b9/nimzo/assets/licensed_tana_vani/tana/ic_room_theme_love.webp','image',true),
('nimzo-apk-theme-supreme-20261021','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/3042cfa7d47238c935e53ec9972dc1f4439738b9/nimzo/assets/licensed_tana_vani/tana/ic_room_theme_supreme.webp','https://raw.githubusercontent.com/adi4ch-cmd/Nimzo/3042cfa7d47238c935e53ec9972dc1f4439738b9/nimzo/assets/licensed_tana_vani/tana/ic_room_theme_supreme.webp','image',true)
ON CONFLICT(item_id) DO NOTHING;
COMMIT;

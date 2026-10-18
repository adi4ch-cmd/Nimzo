# Libra and Aries gifts — source integration, not live activation

**NIMZO IDs**
- Libra: `1178a55b-ebed-59a6-9c6a-efb24893b59b`
- Aries: `1245657f-3156-5724-a601-e2f5c5fd2e35`

Each gift is configured at **100,000 coins per send**, `category=premium`, and has its own new SVG icon. Both records exist in the NIMZO Supabase database with `active=false`. Their `min_vip` and `min_svip` are zero.

App source: the two IDs are permitted through the verified server gift animation event route, and the VAP player is configured for RGB/alpha animations with AAC audio; it does NOT overlay coin prices on the animation. The **authoritative sender debit** and 45% diamond credit / 5% room owner credit continue to use existing backend `send_gift`, `send_profile_gift`, and `send_moment_gift` RPCs (no client balance writes).

**Release blocker, verified against the live database**: no storage objects for Libra/Aries and no rows for either in `public.gift_animation_media`. Activating gifts now could charge users without giving them the requested moving animation. The VAP test media from user ZIP files is not hosted and is NOT a verified watermark-free licensed master; watermark traces and `17ae.com` codeTag remain. No third-party media is published as an approved product.

To activate after verifying commercial reuse rights and file integrity:

1. Use an authenticated **Supabase Storage upload API** to upload each verified VAP v2 MP4 to a stable hosting location. Direct inserts into `storage.objects` are NOT valid uploads.
2. Verify both actual HTTPS media downloads, full 180 frame / 30 fps / six-second playback, alpha and AAC sound on Android and iOS while live voice is active. No static fallback, fake room mockups or price banners in the animation.
3. Add one `public.gift_animation_media` row per gift with its actual HTTPS video_url and `approved=true` only after steps 1–2.
4. Set `public.gifts.active=true` for these exact IDs only when their media is approved and the destination NIMZO app build is able to render them. The price must remain 100000.
5. Smoke test 100K debits / real settled animation events using a controlled funded test account, and confirm no unrelated profiles or wallets change.

**Do not build APK** at this stage; the user explicitly requested source-only work.

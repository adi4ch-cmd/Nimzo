# NIMZO approved gift catalog and premium playback contract
Status: APPROVED SPECIFICATION — NOT YET IMPLEMENTED OR DEPLOYED.
Do not change production gifts, wallets, ledger, accounts, or existing purchases by applying this document.

## Catalog (price in coins : number of distinct gifts)
1000:2
10000:2
50000:3
100000:4
500000:4
1000000:4
5000000:4
10000000:4
15000000:4
35000000:1 (premium)
50000000:1 (premium)
Total: 33 distinct gifts. Names and artwork of individual gifts are pending approval. Do not invent prices for existing named gifts. Do not deactivate old gifts before a tested migration plan handles existing references.

## Premium animation
- Only verified, successfully settled gifts whose UNIT price is exactly 35,000,000 or 50,000,000 coins qualify. Quantity must not turn a cheaper gift into premium.
- Premium gifts trigger a full-screen, high-quality cinematic 2D/video/GIF/animation effect WITH SOUND (not cartoon/emoji/placeholder art) in every active voice room whose normalized country matches the settled gift's source room country.
- Preserve existing room audio, voice session, chat, and microphone controls. Sound must respect mute, user audio settings, platform focus, and volume.
- Display actual sender name, recipient name, gift name and gift quantity. Only use server-authoritative values.
- Emit a durable idempotent broadcast event transactionally with settlement. Never emit on client request, failed transaction or replay. Dedupe by unique gift event id.
- Country is determined on server from authoritative room country code, normalized to ISO-3166-1 alpha-2. No client-supplied country. Ensure membership/access restrictions are respected.
- Subscription can deliver across rooms in that country, including to users already present when event occurs; no cross-country playback.
- Queue overlapping animations, allow close/skip without disrupting voice, preload approved assets, and recover from unavailable media gracefully.
- Use licensed, optimized premium animation assets with sound. Do not claim real premium animation until assets are integrated and tested on Android/iOS devices.
- Do not deploy before staging migration tests, transaction rollback/idempotency tests, cross-country and same-country delivery tests, sound/mute tests and real-device playback verification.

## Implementation status
Current Flutter catalog is loaded from public.gifts via gift_repository.dart; room gifts settle via Supabase send_gift RPC. This file is a locked product contract, not an implemented feature.

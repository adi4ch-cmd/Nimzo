# NIMZO — LOCKED 20 GIFTS + PROFESSIONAL VIP + LION KING ENTRY

**Approved by user:** 2026-10-10
**GitHub:** adi4ch-cmd/Nimzo
**Branch:** feature/profile-reference-redesign
**Type:** Implementation requirements, **NOT** a claim the work is completed.

## 1. Non-negotiable delivery rule

- **Do not build an intermediate APK** during gifts or VIP development. Code, source assets, static analysis, automated tests and asset previews may be pushed and run without generating APKs.
- Only after the complete scope below is implemented and validated, use a single **final** `release(gifts-vip): ...` commit to permit the existing Android verification workflow to build the APK. Explicit `workflow_dispatch` must also only be used for final delivery.
- Do not claim an installable, tested, live-ready artifact before the build succeeds, asset paths/contents are checked, and applicable verification is complete. State any physical-device tests that could not be performed.
- Keep all unchanged NIMZO features and backend permissions intact.

## 2. Gift collection target — exactly 20 approved working gifts

**Six existing active live gifts (keep existing IDs/prices):**
1. Rose
2. Heart
3. Crown
4. Diamond
5. Rocket
6. Sports Car

**Fourteen custom NIMZO gift targets to create/complete:**
7. Kiss
8. Coffee
9. Cat
10. Birthday Cake
11. Teddy Bear
12. Gift Box
13. Panda
14. Diamond Ring
15. Golden Palace
16. Private Jet
17. Luxury Yacht
18. Dragon
19. Golden Dragon
20. Phoenix

All gift images and animations must be original NIMZO-created works or assets with verified commercial-use rights; no misleading, falsely matched or unrelated artwork. Do not import or show third-party app logos or branding. Avoid placeholder emoji/fake-looking catalog cards.

**Every active gift must meet the same complete definition:**
- Its own legible, high-quality picture/thumbnail (transparent PNG/WebP where appropriate), no blank or old mismatched reference image.
- A matching **working moving effect** (2D Flutter particle/transform animations for simpler gifts; appropriately produced and verified SVGA/MP4 or comparable cinematic sequence for advanced gifts), not merely an icon pretending to be animation. Unique gift-specific animation treatment; do not falsely describe general sparkle as a licensed premium film.
- Gift catalog name, category, coin price, icon and animation mapping correctly tied to the same authoritative gift UUID.
- Successful **server-settled** room, profile and Moment sends show the right effect/recipient/quantity. Room playback uses real verified events with queueing/deduplication and keeps Vivox room audio/microphones connected.
- Safe quantity selection, sender including self-gift, recipient selection, sufficient-funds validation, retries/idempotency, atomic wallet debit and ledger preservation, loading/error/permission states. No client-side coin grants.
- Artwork and animation playback must support narrow Android screens and gracefully fail without blocking the room.

**Economy and data rules:**
- Existing six live gift IDs and prices are authoritative, and historical transactions are preserved.
- Four older catalog rows previously deactivated due to referenced gift events must remain historically queryable; **do not delete settled financial history** or reset wallet balances/wealth/charm/gift counts.
- New 14 gift UUIDs and coin prices require an explicit approved database plan, tested migrations, RLS/authorization and server pricing; do not invent prices and activate unchecked gifts.
- Do not artificially show "20 complete" in the catalog until all 20 meet requirements.

**Current verified starting checkpoint (2026-10-10):**
- Exactly six active live gifts: Rose, Heart, Crown, Diamond, Rocket, Sports Car.
- Five unused incomplete legacy gift rows deleted; four referenced legacy rows deactivated.
- Six MIT-licensed icon assets and two genuine pinned matching Rocket/Sports Car SVGA sources integrated with source attribution.
- The other 14 custom gifts are **pending creation, backend activation and verification**. This document locks the goal but does not change this implementation status.

## 3. Normal VIP: full professional redesign, preserving backend authorization

- Normal VIP **tiers 1–10**, modern clean **NIMZO green + premium metallic detail**, high-resolution authentic-looking badge, frame, membership card and premium status, no emoji/fake icons, no heavy childish gradients.
- Design and implement a coherent VIP landing page, tier selector, comparison/benefits, verified balance/purchase flow, active/expired status, rewards/eligibility and public/own profile badge/frame; test loading/offline/unauthorized states.
- VIP price thresholds and USD-to-coin conversion must remain as locked in `docs/NIMZO_LOCKED_UI_CONTRACT_2026-10-07.md` and `nimzo/lib/features/vip/vip_tiers.dart`. No VIP subscription activated solely by selecting a tier preview.
- SVIP remains **1–10** with distinct professional black/red/gold styling; keep existing licensed emblems, recharge thresholds, rewards and entitlements unchanged unless part of approved fixes. Do not collapse VIP into SVIP.
- Existing Phoenix/VIP6 entitlement and other profile, room, chat, gift and badge effects must continue to use **server-verified** membership status.
- Protect accessibility, small-screen layout, frame lifecycle, motion reduced preference and audio priority.

## 4. Original "Lion King Entry" (room entrance), not a catalog gift

- Create a **new original NIMZO royal lion** entry identity (regal lion wearing a gold crown; **not** a recognizable character or another app's copyrighted animation).
- Premium entrance visuals: forward approach, royal mane/crown glow, bounded golden particles, roar **only when user audio settings permit**, verified user display name and short premium title, target duration roughly 5–7 seconds.
- Trigger **once** for a genuine new server-verified room join by a user authorized for the selected VIP benefit. Never grant premium entitlement using client selection, fake name, a local timer or test account.
- Do not break/mute active Vivox chat or replay history; debounce duplicate room joins and background/resume events, allow skip/close, clean up controllers.

## 5. Acceptance gates before the only final APK

1. All 20 active gift icon/media paths verified in final asset bundle; original premium and non-premium animations actually render and finish correctly; none use mismatched files.
2. Automatic tests for all gifts, verified send/self-gift/profile/Moment/room event, queue/replay/failed settlement, wallet authorization, quantity and idempotent retry.
3. VIP 1–10 status/tier/benefits and Lion King entrance visuals validated against professional UI references; effects never activate for an ineligible account.
4. Full `flutter analyze`, `flutter test`, backend migration/realtime/RLS and native voice contracts pass.
5. Run final Android CI **once after these conditions**, inspect output APK content, signing/installability and SHA-256. Test actual room gift + lion entry + Vivox coexistence on devices if accessible; explicitly disclose what remains unverified.

**Do not silently substitute a smaller gift list or an incomplete cinematic effect and call the task done. Do not build APKs between individual fixes.**

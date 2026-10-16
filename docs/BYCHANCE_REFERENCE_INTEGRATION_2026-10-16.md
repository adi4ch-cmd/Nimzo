# ByChance 9.2.2 → NIMZO: Verified reference integration

Source: user-supplied ByChance 9.2.2 XAPK, inspected offline on 2026-10-16. This is a **reference study**, not a decompilable Flutter project. Only NIMZO-authored styling is committed here. Do not ship ByChance binaries, logos, music, frames or icons until commercial reuse rights have been confirmed.

## Verified extraction
- Four APK components; Flutter AOT `libapp.so`, DEX, native libraries, resources.
- Bundled Flutter assets: 262 icons, 78 images, 11 frame files (5 animated GIFs), 7 Lottie JSON, 11 onboarding assets and 5 sound files.
- 66 Dart page/view path references; 907 compiled Dart source-path references; 128 possible ByChance API route references.
- Full client binaries and source-path references are **not** buildable Flutter source files.
- No bundled premium full-screen SVGA/MP4 gift catalog, game engine binaries, backend, database schema, signing keys or admin panel source.
- Source XAPK is a static snapshot; no backend testing, purchases or user sessions were carried out.

## Implemented in this branch

| NIMZO area | Actual implementation | Status |
| --- | --- | --- |
| Brand/theme | Violet, pink/coral, blue, orange and lighter page surface in `NimzoStyle` | Changed |
| Navigation | Selected gradient pill in the existing five tabs | Changed |
| Home | Reworked own-room gradient hero, visible room metrics and styled cards; all current data providers retained | Changed |
| Me profile | Violet/coral cover gradient; preserves real profile, level, wallet and links | Changed |
| Royal Store | Violet header and pastel catalog cards; existing purchase/equip transaction code unchanged | Changed |
| Tests | Palette and Material theme assertions | Added |

## Feature parity investigation — no invented working features

| ByChance client feature | NIMZO reuse approach | Requirements before claiming parity |
| --- | --- | --- |
| Audio rooms, microphone seats | Keep existing Vivox + Supabase room sessions | Physical device/RTC reliability verification |
| Gifts and gift box | Keep existing NIMZO server-authoritative gift ledger and overlays | Verify actual production artwork and remote event delivery |
| Frames, entry effects, bubbles | Match appearance with NIMZO-owned/licensed artwork | Commercial rights for extracted third-party assets |
| Royal store and owned bag | Keep existing server-authoritative purchases/equip endpoints | Test idempotence and wallet settlement |
| VIP/SVIP | Retired in current NIMZO route; don't silently reactivate | User-approved entitlement rules and assets |
| Games | Existing NIMZO game catalog | Licensed game source/provider, server-side balance settlement |
| PK and rankings | Feature requires independent Supabase schema plus UI | Audited wallet/rank and room authorization |
| Coins/recharge/traders/withdrawal | Existing wallet remains source of truth | Real payment-provider contracts, anti-fraud, country policies |
| Video streaming and calls | Not in scope: NIMZO is intentionally voice-only | New product decision and explicit camera privacy review |
| Agency/host/reels pages | Excluded by current NIMZO product scope | New product approval before adding |
| Admin panel / remote ByChance APIs | Do not use ByChance server | NIMZO-owned backend code and API credentials |

## Safety and verification
- This branch makes **no database migrations** or account/coin changes.
- Original third-party binary/native libs are **not** copied into the Flutter build.
- Color inspiration is distinct from copying trademarks, private endpoints or UI art.
- Run `flutter analyze`, `flutter test`, device voice, purchases, and the existing Android verification workflow before shipping.
- Passing UI tests alone does not validate Agora ↔ Vivox compatibility or server-dependent gameplay.

## Remaining work (not completed in this branch)
Screenshots/runtime visual diff, NIMZO user-approved custom asset production, and functional room/gift/wallet/game end-to-end tests. APK is not a verified deliverable until CI produces and validates it. This document intentionally distinguishes present from absent work.

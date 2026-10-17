# NIMZO — Tingle Reference Full UI/Functionality Acceptance

Reference: Tingle v5.0.19 screenshots supplied on 2026-10-17.
Development: feature/tingle-ui-rebuild-20261017.
Status: **NOT FINISHED. NO APK BUILDS AUTHORIZED.**

## Non-negotiable locked constraints
- Exactly **10 microphone seats**, not the 12 shown in the reference.
- App stays branded **NIMZO**; Flutter, Supabase and existing Vivox integration.
- Audio-only NIMZO product. Do not silently add video chat or video calls.
- Preserve all existing profiles, IDs, wallet coins, diamonds, social records,
  messages and permanent rooms. No destructive migrations.
- Never simulate gifting, purchases, rewards, mic sessions, membership status,
  users or balances. Bind screens to trusted server results.
- Do not copy Tingle's nonlicensed proprietary assets/logo/media.
- **No APK/AAB/Google Play builds until ALL acceptance criteria pass.**
  The old APK workflow has no push/PR triggers and requires explicit manual
  confirm_complete. Push QA may run Flutter analyze/isolated tests only.

## Checklist (each row requires screenshot comparison + button/data QA)
| Reference | Present state | Blocking work |
|---|---|---|
| Splash/Login/OAuth | Login reference layout, email/Google linked | Mobile/quick auth, icon/pixel QA, on-device OAuth |
| Register/Profile details | Rebuilt reference-like profile form, real avatar save | Referral service, exact artwork, edit/picker device tests |
| Explore/New/Follow/PK | Three tabs + real country filtering | PK live data, full visual parity, badge/frame artwork |
| Daily Check-in | Unavailable | Verified daily attendance RPC and reward settlement |
| Profile summary | Purple reference-inspired menu + level + edit + VIP links | Complete badge/account stats and avatar decoration art |
| Coins/History/Recharge | Real wallet/ledger and navigation | Full payment QA, visual parity, offline recharge integration |
| Store | Server-authoritative medals, Bag, category tabs | Catalog for frames/entries/bubbles/rides, premium assets |
| VIP/SVIP | Tier previews based on backend membership state | Server grants, artwork, 3D effects, rewards, eligibility |
| Levels/Game Levels | Existing working counters UI | Reference layout, progress validation |
| CP Space | Existing CP backend | Reference graphics, interactions |
| Daily/Growth Tasks | Real event-backed indicators | Server payout and reset contract, mic duration attestation |
| Settings/Blocked/Help/Delete request | Database-backed screens | Exact designs, private call scope, request policy QA |
| Audio Room | Existing NIMZO room and Vivox | Reference mic layout, controls, entry/profile/permission QA |
| Mic sheet/Moderation | Existing controls | Reference actions, speaker mute/lock owner checks |
| Music and reactions | Existing implementations | Exact player, real animation assets |
| Friends list and filters | Existing follows and friends | Reference tabs, cards, actions and verification |
| Moments feed | Discover/Following real filters, existing actions | Post-editor parity, attach/mentions, image tests |
| Messages | Existing chat | Reference header/tabs/cards, unread/blocked QA |
| Gifts | Existing gifts/settlement contract | Licensed premium 3D animations + native playback QA |
| Games | Existing catalog/round backend | UI/icon parity for every game and fair settlement QA |
| Room photo/create | Reference UI, real upload path | Camera/device/storage policies/private room end-to-end |
| Ranks/families/agency | Existing partial or missing | Service contracts and design matching |
| Visual QA | Not performed | Record comparison of every supplied screenshot at same device |
| Automated QA | Existing old suite had 44 failed tests | Fix regressions and ensure all critical tests pass |
| Native Android/iOS | Existing repo Android scaffold only in CI | Final packaging, permissions, SDK QA, release signing |

## Definition of complete
1. All navigation reaches functional screens, not placeholder pages.
2. Every interactive element either has a verified backend operation or
   is absent; no decorative fake affordances.
3. Database RPCs verify entitlements, daily rewards, game odds, coin exchange,
   GIFTS and anti-duplicate purchases.
4. All reference designs are compared at the same Android viewport and
   visually reviewed. Missing asset licensing remains a release blocker.
5. 10-seat Vivox voice join/leave, mute, permissions and reconnect validated
   on multiple devices. Existing historical user data persists.
6. Relevant tests pass without continue-on-error; Android and iOS builds
   can happen **only after** this checklist is fully satisfied.

## Work completed since prior partial test APK
- Auto APK workflow disabled; manual full-completion gate added.
- Added source-only QA and ten-seat regression test.
- Reference-inspired VIP/SVIP tier UI (read-only, not a purchase mechanism).
- New Moments Discover/Following presentation tied to real follow records.
- Store category UI for active medals and honest empty categories.
- Existing backend auth, profile, wallet, room/photo, social data remain
  available. More work is required to call this a full clone.

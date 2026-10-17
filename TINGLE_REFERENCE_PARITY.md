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
| Splash/Login/OAuth | New lavender splash/onboarding + linked email/Google login | Exact artwork, mobile/quick auth, pixel QA, on-device OAuth |
| Register/Profile details | New lavender signup, password confirmation, terms toggle, real Supabase sign-up; profile edit/upload preserved | Referral backend, exact artwork and device tests |
| Explore/New/Follow/PK | Three tabs + real country filtering | PK live data, full visual parity, badge/frame artwork |
| Daily Check-in | Server-side UTC check-in table + idempotent RPC deployed; lavender 7-day claim UI wired | Reward amount intentionally unconfigured, authenticated device QA and full visual parity |
| Profile summary | Purple reference-inspired menu + level + edit + VIP links | Complete badge/account stats and avatar decoration art |
| Coins/History/Recharge | Real wallet/ledger and navigation | Full payment QA, visual parity, offline recharge integration |
| Store | Server-authoritative medals, Bag, category tabs | Catalog for frames/entries/bubbles/rides, premium assets |
| VIP/SVIP | Tier previews based on backend membership state | Server grants, artwork, 3D effects, rewards, eligibility |
| Levels/Game Levels | Compact reference-inspired Wealth/Charm/Active progress UI using verified server totals | Pixel parity, all tier icons and device QA |
| CP Space | Pink reference-inspired CP hero + real search/invite/accept/decline and couple status | Exact licensed graphics, timing/badge artwork and device QA |
| Daily/Growth Tasks | Real event-backed indicators | Server payout and reset contract, mic duration attestation |
| Settings/Blocked/Help/Delete request | Database-backed screens | Exact designs, private call scope, request policy QA |
| Audio Room | Existing NIMZO room and Vivox | Reference mic layout, controls, entry/profile/permission QA |
| Mic sheet/Moderation | Existing controls | Reference actions, speaker mute/lock owner checks |
| Music and reactions | Existing implementations | Exact player, real animation assets |
| Friends list and filters | Existing follows and friends | Reference tabs, cards, actions and verification |
| Moments feed | Discover/Following real filters, existing actions | Post-editor parity, attach/mentions, image tests |
| Notifications | Rebuilt purple notifications page, real categories, unread state, mark-read RPC | Pixel parity and push delivery device QA |
| Messages | Rebuilt Inbox with real conversation RPC, search/unread tabs, Friends/Notifications links | Screenshot parity, blocked/typing/receipt device QA |
| Gifts | Existing gifts/settlement contract | Licensed premium 3D animations + native playback QA |
| Games | Premium seven-game tab/categories and existing room game picker; unsupported game boards clearly marked Preview | Backend games for missing slugs, real payouts, artwork and QA |
| Room photo/create | Reference UI, real upload path | Camera/device/storage policies/private room end-to-end |
| Ranks/families/agency | Existing partial or missing | Service contracts and design matching |
| Visual QA | No same-device screenshot pass yet | Record comparison of every supplied screenshot at same device |
| Automated QA | Source-only PR QA: Flutter analyze + ten-seat/roster tests passed (run 39019844054); old full suite previously 44 fails | Fix full-suite regressions and device checks |
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

## 2026-10-17 continuation checkpoint
- New reference-inspired account registration and onboarding are wired to
  the original Supabase auth flow, with no extra temporary account tables.
- Level, CP and game catalog pages redesigned; real NIMZO data is used and
  no pretend membership/grants/bets are accepted.
- A new 7-game roster test and a server-unavailable preview test guard against
  misrepresenting gambling or rewards as real settlements.
- Verified source-only GitHub Actions PR run **39019844054** passed (Flutter
  analyzer and focused tests). This run contained **NO APK/AAB build steps**.
- Full reference matching is **NOT** achieved. The release lock remains.

## Latest continuation: Messaging and check-in
- Inbox and Notification screens now use reference-like cards/filters while
  keeping existing messages, notification RPCs, and unread states.
- Migration `20261017090000_daily_checkins.sql` was syntax-tested with a
  transaction rollback and deployed to the NIMZO Supabase project.
- `daily_checkins` and `claim_daily_checkin()` exist with authenticated-only
  access and own-row RLS. Unauthenticated RPC rejection was verified.
- The reward setting `daily_checkin_reward_coins` has NOT been provisioned.
  Claims are disabled by default until a deliberate economy decision. No
  coins were created or balances changed during migration verification.
- Existing `send_gift` implementation credits **45% diamonds** to recipient;
  no financial settlement code was edited in this run.
- GitHub source-only QA **39020448164** passed; **no APK was built**.

## 2026-10-17 continuation: regression and asset verification

- Verified historical full-suite failure count: **248 passed / 57 failed** in
  run 39020601556. Source/static analysis and 10-mic constraints passed.
- Follow-up run 39021171755 improved this to **257 passed / 48 failed**.
  Remaining failures include missing image/animation assets, older Hilo/ByChance
  UI assumptions, narrow-phone room layout, and unfinished voice-room/game QA.
- Regression fixes pushed in this continuation: Material ancestors around
  Settings and Profile ListTiles; notification mark-read accessibility;
  onboarding small-device scroll overflow; required scrolling when testing
  logout; updated stale blank-UI, color, follow-label, and membership tests;
  honest unavailable level labels and safe image fallbacks.
- Production gift catalog has **20 active gifts** and paths recorded in the
  gifts table, but **zero approved entries in gift_animation_media**, and no
  animation objects in the gifts storage bucket. Original premium animated
  gift parity remains blocked by missing verified media. Do not mark complete.
- Checked real Supabase gift functions: room, moment and profile senders settle
  **45% recipient diamonds**. No account, gift or wallet balances were
  changed in this audit.
- APK workflow has manual-only trigger and an additional non-existent
  `CLONE_RELEASE_READY` file guard plus full-suite test requirement.
  This gate intentionally blocks ALL early builds. It must not be created
  until reference screenshots, device QA, animation/licensing, 10-seat and
  all server-authoritative feature tests pass.

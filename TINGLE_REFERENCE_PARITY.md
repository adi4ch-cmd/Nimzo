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
| Splash/Login/OAuth | Lavender onboarding/email/Google + real Supabase phone SMS OTP login, complete E.164 guard | Phone provider/device SMS delivery, Quick Login, exact art, OAuth and pixel QA |
| Register/Profile details | New lavender signup, password confirmation, terms toggle, real Supabase sign-up; profile edit/upload preserved | Referral backend, exact artwork and device tests |
| Explore/New/Follow/PK | Explore/New/Follow plus consent-based live PK challenge screen and server gift-event score RPC | Battle device QA, timer/realtime refresh, full visual and licensed artwork parity |
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

## 2026-10-17 late continuation: Moments editor / remaining visual tests

- Redesigned **Create/Edit Moment**: white app bar, lavender canvas,
  premium share banner, accessible multi-line input, full-width
  camera/gallery selector, same Supabase media upload and save/edit logic.
- No fabricated comments, likes, gifts, media or post counts were added.
- The last complete full-suite run **39027768033** passed **304 tests**
  and failed **3 golden-visual test cases** (all the nonvisual and
  server-related tests in that run passed). The failing visual baselines:
  `master_visual_preview_test.dart` (treasure_final),
  `reference_preview_test.dart` (empty Home and board images),
  `remaining_visual_qa_test.dart` (catalog).
- These goldens were created against prior NIMZO layouts and now differ
  from the active Tingle-inspired redesign. **Do not delete golden tests,
  silently update their baselines or mark them passed.** Review the actual
  images against user references and approve replacement baselines only
  after device screenshot inspection.
- Latest Moments editor change is in commit `de7efb1404ce8b01bbe5c6f5f1e2b3bfed81b89a`.
  Its source-only CI run is `39042436128`. No APK was requested or built.
- Remaining high-priority release blockers: licensed premium media and
  playback, real frames/entries/bubbles/rides catalogs, PK data/services,
  mobile/quick auth, signed device smoke on two phones, full 10-seat
  Vivox reconnect/permissions, and pixel-by-pixel review of every
  supplied reference page.


## 2026-10-17 full-suite gate, run 39043031546

- Flutter analysis, 10-seat constraint, asset bundle, and 390px Friends
  interaction checks passed. **No APK or AAB was built.**
- Whole Flutter suite: **305 passed, 3 failed**. Remaining failures
  are screenshot/golden comparisons, NOT missing voice functionality:
  1. `master_visual_preview_test.dart`: treasure_final golden 99.51% changed.
  2. `reference_preview_test.dart`: home_empty golden 99.99% changed;
     game boards also have a ~0.12% single-row/anti-alias variance.
  3. `remaining_visual_qa_test.dart`: catalog golden 86.30% changed.
- The proposed new screenshots are uploaded as
  `nimzo-golden-candidates-unapproved` on that run. Do **not**
  automatically approve/generate new baselines merely to turn CI green.
  Compare with the provided Tingle references and review every altered
  icon, frame, color and interactive state first.
- Fixed Moments attachment widget test so the below-the-fold photo chooser
  is reached by actual scrolling. Camera selection/remove UI now passes
  with mocked uploads; no fake network photo is assumed.
- Audio room Android back now uses the same exit confirmation as the
  room-header close action, with duplicate-dialog protection and safe
  Vivox cancellation.
- The full clone, native device QA and the final APK remain blocked until
  reference parity and backend coverage are actually complete.

## 2026-10-17 14:59 UTC regression checkpoint
- Restored the real Moments photo choose action to the initially visible
  position above the caption, keeping camera/gallery, upload, replace and
  removal logic unchanged. The full-suite photo-picker regression now passes.
- Validated repository image assets in both checkout and Flutter rootBundle;
  the asset-bundle integrity test passes. Previous unbundled-image failures
  must not be treated as missing source artwork without independent evidence.
- Latest complete source-only CI run **39042948058**: 305 tests passed, 3
  tests failed. Failures are screenshot comparisons in
  `master_visual_preview_test.dart`, `reference_preview_test.dart`, and
  `remaining_visual_qa_test.dart`. These are **NOT** marked as accepted.
- CI now generates `nimzo-golden-candidates-unapproved` plus original
  golden diff evidence for comparison. They are artifacts for manual visual
  QA only: no automatic baseline updates are checked into the repository.
- Golden differences do not prove Tingle pixel parity. Original reference
  screenshots and custom premium art still require device-by-device review.
- **No APK/AAB/release build was triggered.** Ten microphone seats remain
  the locked audio-only configuration.

## 2026-10-17 PK milestone — no APK
- Added non-destructive migration `20261017210000_room_pk_challenges.sql`
  and deployed it after successful transaction/rollback dry-run.
- Only public room owners can request or accept five-minute PK. The invited
  owner must explicitly consent; authenticated-only RPC grants and own-room
  invitation row policies are enforced on the server.
- `pk_live_board()` computes A/B scores only from committed gift events in
  the match window; there are no new wager, coin, diamond or VIP mutations.
- Real PK screen is reachable from Home/PK and active audio room header.
  Room session remains mounted, and seat-count rules are untouched (10).
- Anonymous RPC attempts were rejected. Verification showed **zero fabricated
  invitations and zero PK matches**. User wallet balances were not changed.
- PK room-to-room live device QA and visual comparison are pending; the
  full clone is not complete and APK/release gates remain locked.
- Latest source-only CI before PK passed 305 Flutter tests; only 3 golden
  screenshot comparisons failed on run 39043313670. Those golden baselines
  remain unapproved, NOT auto-updated.

## 2026-10-17 phone authentication continuation
- Tingle-style Mobile login is no longer an inert shortcut: it requests a
  real Supabase SMS OTP, verifies the code, and allows persistent auth sessions.
- E.164 country prefix and OTP format validation implemented, plus visual
  phone step, terms control, editable number and auth failure feedback.
- Fixed auth domain mapping: phone-confirmed, email-less accounts no longer
  get sent to an impossible email-verification page.
- The Supabase SMS provider configuration and delivery on physical devices
  remain unverified, so production SMS must **not** be declared complete.
- Added source-only CI tests for valid phone formats and login redirect.
- Real PK scoring, consent and OTP work do not modify the ten-seat rule.
- Full clone / reference match is NOT complete; final APK build remains locked.

## 2026-10-17 latest verified source-only QA (no APK)
- Source-only workflow run **39053724116**: analyzer, asset integrity,
  ten-mic constraints, Friends, PK score and Mobile OTP routing all passed.
- Full Flutter suite **310 passed, 3 failed**. The three failures are
  previous visual golden comparisons in `master_visual_preview_test.dart`,
  `reference_preview_test.dart`, and `remaining_visual_qa_test.dart`.
- Golden candidate/diff files exist as CI review artifacts only. No golden
  baselines were auto-approved; no APK/AAB/release workflow was triggered.
- Remaining launch blockers include original-quality licensed animated
  media, server-catalog frames/entries/bubbles, phone SMS delivery QA,
  in-room Vivox PK and ten-mic device testing, and direct reference
  screenshot parity review.

## 2026-10-17 responsive Home correction (NO APK)
- Home Explore/New/PK/Follow tabs now use a horizontally scrollable tab
  strip on narrow Android screens. Search and Rankings remain fixed and
  accessible rather than being pushed offscreen.
- Country chip flexes inside its row; filter remains accessible.
- Added `home_narrow_layout_test.dart` at **320 dp** and 1.35× text
  scaling, using empty real-data providers without inventing rooms.
- This does **not** approve the three outstanding visual golden differences.
- No APK/AAB or release build was requested. Ten microphone seats unchanged.

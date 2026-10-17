# NIMZO UI-first visual reconstruction — reference inventory

Date: 2026-10-17. Branch: `feature/tingle-ui-rebuild-20261017`.
Source of reference: user Library Tingle v5.0.19 XAPK, technical audit,
reference screenshots at 691×1536 and room video. These screenshots are
reference-only; they are not original Flutter/Dart source or a license to
redistribute proprietary Tingle graphics. Use independent NIMZO branding.

## Workflow locked by owner
1. First complete the entire visible app: every screen, icon, layout, bottom
   navigation, tab, modal, empty/loading/error state and interaction.
2. Compare each screen at the same device viewport and text scale to the
   supplied images and walkthrough videos. Do not mark a UI screen complete
   merely because it compiles or its old golden baseline passes.
3. Use original/permissioned media or custom artwork for unavailable premium
   icons/frames. No Tingle logos or remote assets by hotlink.
4. Preserve NIMZO's 10 microphone seats (reference shows 12), audio-only app,
   package identity and existing Flutter navigation. Do not add video.
5. Defer backend upgrades, new economy/reward/game settlement services and
   migrations until **after UI acceptance**. Preserve the existing Supabase
   reads and safe action handlers; do not simulate balances, users or rewards.
6. Do not disable existing UI checks, auto-accept stale screenshot goldens,
   merge this WIP branch, or release APK/AAB before final acceptance.

## User-Library screenshots mapped to NIMZO Flutter screens

| Screenshot | UI surface and exact reference inspection | Flutter UI | State |
|---|---|---|---|
| 1000117869.png | Sign-in, logo/title, gradient, email/password, mobile/Google/quick action, terms | auth/tingle_login_screen.dart | Needs pixel QA |
| 1000117870.png | Profile Details, avatar, name, ID, age, referral, country, gender, save | auth + profile/profile_setup_screen.dart | Needs pixel QA |
| 1000117871.png | Daily check-in purple overlay, 7-day reward tiles, gold CTA, close | profile/tingle_daily_checkin_screen.dart | Reskinned; still needs same-phone comparison |
| 1000117873.png | Settings white compact rows, purple control, logout/delete | settings/settings_screen.dart | Compact-row UI patched; inspect toggles |
| 1000117874.png | Coins orange balance hero, purple recharge, compact ledger and filter | wallet/tingle_coins_screen.dart | Compact UI patched; needs golden |
| 1000117875.png | SVIP 1 purple regal art, horizontal tier bar, six perks | profile/tingle_membership_screen.dart | No license/3D parity |
| 1000117876.png | SVIP 2 green regal art | profile/tingle_membership_screen.dart | No licensed visual parity |
| 1000117877.png | SVIP 3 pink regal art | profile/tingle_membership_screen.dart | No licensed visual parity |
| 1000117878.png | My Profile category icons and menu rows | profile/tingle_me_screen.dart | Partial |
| 1000117879.png | My Store circular category icons, recommended 2-column goods | store/store_screen.dart | Partial |
| 1000117880.png | Avatar Frame preview and category grid | store/store_screen.dart | Partial; no fake goods |
| 1000117881.png | CP Space elaborate heart hero, days counters and Bind CP | profile + couple pages | Partial; assets missing |
| 1000117882.png | Dark blue Level header and compact coin level ladder | profile/levels_screen.dart | Partial |
| 1000117883.png | Task daily/growth sections, small white cards, icons and purple Go buttons | profile/tingle_tasks_screen.dart | Compact-row UI patched |
| 1000117884.png | Create Audio Room violet gradient, image picker, name, description, public/private, live | rooms/presentation/create_room_screen.dart | Partial |
| 1000117885.png | Audio room: header icons, 4×3 reference mics (NIMZO must keep 5×2), purple grid, chat bottom bar | rooms/presentation/room_screen.dart | Incomplete pixel/layout review |
| 1000117886.png | Room empty-seat sheet, Seat Here/Give/Lock/Mute/Cancel | rooms/presentation/room_screen.dart | Needs permission-safe UI pass |
| 1000117887.png | Room in-place music panel | rooms/presentation/room_music_screen.dart | Partial |
| 1000117888.png | Friends purple selected tab, profile rows, follow pill state | social/tingle_friends_screen.dart | Reskinned, fixed widget margin |
| 1000117889.png | Reaction bottom sheet, six emoji icons and close | rooms/presentation/room_screen.dart | Needs screenshot QA |
| 1000117890.png | Exit Room confirm white rounded dialog on dimmed room | rooms/presentation/room_screen.dart | Existing action; needs visual pass |
| 1000117891.png | Post Moments: image placeholder, text area, Mention and topic chips | moments/moments_screen.dart | Needs exact visual pass |
| 1000117892.png | Home Apply Filter sheet: country title, search field, flag chips | home/home_screen.dart | Custom sheet patched; QA pending |

Other screenshot files and large video `screen-20261017-034445.mp4`
are stored in the user's Library; they must be reviewed for every distinct
visual state, transition and modal, not treated as an automatic source-code export.

## Committed UI-only work in this batch

- `b642143`: Coins card, recharge strip and ledger spacing reduced to match
  compact reference proportions.
- `ccbeb5b` / `7ea4efa`: Friends tabs/cards/follow states reskinned;
  fixed invalid negative margin detected by Flutter widget tests.
- `34dc682` / `8d43271`: Check-in lavender/gold seven-day display reskinned,
  preserving existing claim RPC and backend status.
- `1e8229a`: Daily/growth task item icons and rows resized.
- `b941b50`: Settings row typography and vertical spacing resized.
- `214db2b`: Home country picker replaced with a searchable flag-chip
  bottom sheet using the existing country picker model. No database mutation.

## Acceptance gate for each of the 23 reference surfaces

- Compare artwork/icon placements, fills, borders, shadows, typography, gaps,
  clipping, icon size, Android system bars and bottom tab arrangement.
- Compare at reference ratio and additionally 320/360/390dp small phones.
- Test every tap/click/back/scroll/toggle and all visible tabs.
- Test empty, loading, failed and populated views separately (no invented
  online users, membership items, lucky balances or bet payouts).
- Mark complete only after reviewed screenshot difference and working route.
- Keep three unresolved golden tests visible until visual baselines are
  manually inspected and approved; an old CI visual failure is **not** proof
  that the current reference matches.

This is a UI work inventory, **not a finished-build certificate**.


## UI-only continuation — latest checkpoint

Backend and game logic are **explicitly out of scope**, including coin or
diamond grants, membership activation, paid store purchases, microphone
moderation RPCs and game settlement. No migrations were made in this batch.

This source-only pass implemented these visible layouts while preserving the
existing real actions wherever already supported:

- Store `7ee2422`: My Store header, category tiles, responsive verified
  recommendations and compact visual sizes.
- VIP/SVIP `f99e1cd`: horizontally scrollable tiers 1–5, purple/green/pink
  palettes, locally drawn ornate jewel banner, and six privilege cards.
  Existing entitlement backend is read-only and shown as a verified/error
  state; previews do **not** purchase or grant VIP.
- CP Space `0a2a30b`: ornate pink-purple heart hero, unlabeled-inventory-free
  day/hour/minute/second placeholders, couple avatar presentation, and Bind CP
  button that scrolls/focuses the existing partner search.
- Store category preview `8aff7d8` + `e141f37`: 3-column selectable original
  artwork design gallery; selectable preview only, no fictitious prices,
  owned states or checkout. `aa3fa84` preserves featured catalog on back.
- Create Audio Room `7406620`: original layered mountain backdrop behind
  existing safe camera/gallery, room-name/type and Go Live inputs.
- Room Exit `8d133a6`: white rounded dialog, red exit emblem, pastel Keep
  and Exit buttons, retaining voice-safe cancel behavior. Regression test
  `fa0d8da`.
- Room Music `6d51c83` + `635a75d`: reference bottom-sheet player on top
  of the dimmed room with real local audio picker, seek, play/pause, skip and
  volume controls. It **does not** broadcast music through Vivox.
- Main Profile `cfd46c6`: quick navigation card/menu first, real account
  identity and VIP/SVIP shortcuts kept below rather than crowding first fold.
- Widget test `0f8818c`: category gallery tap and 320/390dp layout smoke
  checks. VIP tests now scroll into below-the-fold privilege section
  (`f416493`).

Latest completed source-only CI before this checkpoint (SHA
`cfd46c6`, run `39066511254`): Flutter static analysis, asset bundle,
constraints, focused Friends/PK/OTP tests passed; 317 full-suite cases passed.
Three legacy **golden snapshot suites** still fail (Treasure overlay, previous
Home/game boards, remaining Catalog). They have deliberately not been updated
to claim unreviewed pixel parity. A current on-device screenshot comparison
is still needed, and proprietary 3D Tingle artwork has not been copied.
No APK/AAB build or release was triggered.

## Release gate still open

UI routing and visible core surfaces are substantially implemented, but
**pixel-perfect** recreation of every screenshot/icon/animation, native
device QA, unapproved golden diffs, and all deep modals are not yet certified.
Do not mark the full A–Z UI complete until verified. The user explicitly
requested backend and games to remain deferred, not removed.

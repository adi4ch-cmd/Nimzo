# NIMZO final master UI inventory

Reference: `nimzo-ui-2.html`, SHA-256 `f3401ddc3d565428a07697a5f21e416ef5e34329450e6eda78b149e425bbf4e2`.
Starting commit: `9c8896351db004b982d0f9c301e458857d7b7f2f`.

Read all HTML/CSS/JavaScript before implementation. Embedded assets were inspected by group; the file is immutable. Later function definitions override earlier definitions. No APK or legacy reference is used.

## Screen/component/state inventory

| Area | Screens, components, states in final reference |
| --- | --- |
| Foundation | White 480px maximum viewport; ink #14201a; muted #6b7a72; lavender surfaces #faf5ff, dividers #e9def8; purple/pink gradient; 14px body; 16px headers; 22px gradient tab titles; 18px sheet corners; 45% black scrim; rounded toast; five bottom tabs with 22px line icons and 11px labels; safe areas, Arabic RTL navigation. |
| Auth | Purple/magenta gradient, decorative translucent circles, glass N monogram; Login/Sign up segment; email/password icons; validation; password reset link; gradient submit/loading; Google/Facebook brand icons; terms/privacy footer; setup profile; password recovery and email verification supported by app. |
| Home | Gradient NIMZO title, search/bell/country chip; country search sheet and selected country; own-room avatar/name/banner/open action; Popular/Followed/Recent tabs and empty states; room avatar/name/ID/online/gift total rows. |
| Games catalog | Seven 64px artwork tiles in three columns; room game sheet in four columns. |
| Fruit Party Jackpot | Eight fruit cells around center drawing timer, individual colors, multipliers 5/5/5/45/5/25/15/10; artwork multiplier strip; five amount chips; selected chips/bets; max six selections; potential win/profit; results; auto-play/place/locked/winning states; rules sheet. |
| Grady Pro | Ten tiles in five columns; top vegetables/bottom meat; Pizza and Mixed Meat special selections; multipliers; five chips; max six bets; shared board controls/results/rules. |
| Bigetar | Eight car marque discs around timer; BM/PO/LR/FE/LB/BU/RR/MB; multipliers 8/18/66/50/100/88/30/20; five chips; shared board controls. |
| Slot Jackpots | Four jackpot cards; 5x3 artwork reels, gold outer border; five chips, spin, results/spinning state, rules. |
| Teen Patti | Three player cells with artwork, card hands, odds 2/9/2; max three bets; shared controls. |
| Lucky Wheel 77 | 190px wheel, eight colored sectors, labels x2/x5/x10/x20/x50/x100/x150/x5, gold rim and center 77; selected amount, spin/results/rotation; rules. |
| Bounty Football | Home/Draw/Away artwork tiles, odds 2.5/6/2.5; max three bets; shared controls. |
| Voice room | Compact avatar header/name/ID/online/gift total; exactly ten 52px mic circles in two rows of five; dashed lavender empty seats, occupied/speaking/muted/locked states; chat notice and sender bubbles; tools/effects/message/mic/games/gradient gift toolbar; chest/gem floating buttons. |
| Room gifts | Balance, recipient chips, three-column dark gift cards; 13 embedded gift artworks, price/name; full-width gold-bordered World Crown; insufficient balance, send state; national legendary description; existing confirmation/retry retained. |
| Room tools | 13 artwork tiles: Broadcast, Gathering, Room PK, PK, Wheel, Mora, Treasure, Prize, Calculator, Vote, Music, Video, Clean. Broadcast textarea; gathering title/time; wheel participant/result; Mora choices/score; prize input/winner; gift calculator/clear; vote question/options/progress/end; music player/progress/track rows; shared-video input; clean chat; PK countdown/two avatars/VS/score bar/support/winner states. |
| Treasure/crystal | Room/World segment; total chips, quantity 6/10/20/30; All/Fans/On mic conditions; send/refund note; crystal hero, five progression gems, progress, TOP1/prize artworks and reset note. |
| Room profile/settings | Profile/Member/Activity tabs; announcement/country/level progress; reward/support/certification/activity/banner rows; room medals; Top/Setting actions; edit room avatar/name/announcement; settings profile/name/theme/password/exactly 10 mic seats/dice/fee/member entry/live mode/record/permissions/blocked list/action record/dismiss. |
| Moments | Gradient title/add; lavender post cards, avatar/name/delete, text/optional photo, liked/unliked counts/comment action; empty; New moment textarea/photo preview/Post; comments sheet with sender bubbles/input. |
| Messages | Gradient title; avatar/name/last message/unread purple count; conversation avatar/name/profile link; incoming lavender/outgoing gradient bubbles; message pill and gradient send. |
| Me | Purple/magenta cover, bordered avatar/online dot, crown/name/age/gender/ID/country; three level badges; Following/Followers/Visitors; overlapping white shortcut cards; Task/Store/Ranking/Honor Wall; gold SVIP/pink Wallet banners; CP/VIP/Settings/Level/About; latest-three gift ranking cards with medal/name/ID/amount. |
| Public/edit profile | 130px dark or uploaded cover/back/more; 78px overlapping avatar/online dot; crown/name/age/country/ID/level badges; bio/social counts/interest chips; CP gold-bordered red panel and day badge; medal/frame/car/gift artwork rails/View All; own Edit profile or Follow/Add Friend/Gift footer; photo/cover/display name/gender/DOB/country/bio/Save. |
| Social/search/CP | Search name/ID/results/follow states/empty; Following/Followers/Visitors avatar rows/visited today/follow controls; Choose your CP user list; existing CP invitation/accept/decline/cancel maintained. |
| Levels | Wealth/Charm/Active tabs; distinct badge icons/colors; current level/tier; XP progress/next level; growth explanation; Brown 1–20, Green 21–39, Blue 40–59, Pink 60–79, Red 80–99, Gold 100–120 legend. |
| VIP1–10 | Dark radial purple page, Cinzel gold headings/Poppins body; animated winged shield/crown/ribbon SVG emblem; halo/rays/sparkles/float/shimmer; ten tier selector; status; frame/mic aura/tag/nickname/list background/room theme/front rank previews; animated room theme VIP3+; all-frame rail; sticky gold Get VIP CTA; actual price/status from backend. |
| SVIP1–10 | Winged hero, four feature cells; actual status/progress; nine privilege cells; ten colored tier cards with recharge/coin equivalent/weekly reward/90 days; NEXT badge; four rule cards; gold recharge CTA. Targets $50/200/500/1000/3000/10000/30000/75000/200000/500000; weekly 2/5/10/20/40/80/150/250/450/800M; Sunday 21:00 Saudi display rule. |
| Wallet/recharge | Gradient balance/Coins; rate card; recharge; six two-column amount tiles $1/5/10/50/100/200; payment sheet Card/Google Pay–Apple Pay/Local wallet; country/payment verification note. |
| Task/store/honor | Three lavender task cards/Claim; four store cards (Gold Frame/VIP Frame/Eagle Car/Jeep Car) in two columns with prices; five medal artworks and two room medals on Honor Wall. |
| Ranking | Gift/Wealth/Charm/Active tabs, Daily/Weekly/Monthly chips; 2–1–3 podium with larger raised winner; rank 4+ avatar/name/ID/score rows. |
| Notifications/settings/about | Notification avatar/event/time rows; lavender settings menu Account/Privacy/Language/Help/About, message/gift switches, outlined Logout; account email/reset; privacy visitor/message/online switches; English/Arabic choices; three FAQ rows; About NIMZO/version card. |

## Implementation plan

UI-only: preserve repositories, database schemas, auth/session, Vivox, financial and game settlement logic. Render unavailable service actions without synthesizing authoritative state.

1. Add reference presentation primitives: gradient text/button, compact tabs, balance panels, dashed seats and reference artwork. Extract missing embedded assets byte-for-byte. Update theme and reference source annotations.
2. Rebuild VIP/SVIP views, emblem SVGs and tier previews against final HTML. Use existing membership status and display-only tier data.
3. Complete room header/seats/chat/toolbar and add tools/effects/treasure/crystal/profile presentation views. Keep service actions unchanged or unavailable.
4. Bring all seven game board presentations to final HTML while preserving unavailable settlement state; add multipliers, colors, marque markers, chips, rules and reference controls.
5. Apply Home/Auth/Me/Profile/Messages/Moments/social/recharge/ranking/levels/settings/Task/Store/Honor refinements. Use live data and actual empty/loading/error states.
6. Analyze, run widget/regression tests, regenerate affected UI goldens and inspect screenshots; audit changed paths and immutable HTML hash. Document remaining visual/service limitations candidly.

## Review focus

- 320px phones and long labels: no clipped controls or RenderFlex errors.
- Large text and keyboard: sheets/pages scroll; primary action stays reachable.
- Ten seats only, including missing backend seat records and occupied/muted state.
- Existing retries, message drafts, gift idempotency, logout and reconnect remain intact.
- No fabricated balance/rewards/ranks, backend mutation, or reference-file edit.

## Delivered pass and remaining limits

The complete final HTML was read before implementation. Its later JavaScript overrides, rather than earlier duplicate functions, define the inventory above. The original HTML remains immutable. No APK or legacy reference was used for visual decisions in this pass.

Updated Flutter presentation covers authentication, Home, seven game boards, the two-by-five voice seats, room toolbar/profile/settings, party tools and forms, treasure/crystal/effects/music/PK views, gift sheets, Moments, messages, Me and public/edit profiles, search/social/CP, Levels, VIP/SVIP, wallet/recharge, Task, Store, Ranking, Honor Wall, notifications, settings/account/privacy/language/help/about and shared sheets/buttons/navigation sizing. Existing data, financial settlement, authentication, voice and game-service contracts are retained.

This is a broad visual implementation pass, not a claim of complete pixel parity. Remaining differences:

- Backend-dependent prototype actions stay unavailable: game execution, membership purchase, task claims, store purchases, treasure/crystal rewards, PK/music and party-tool execution. No prototype balances, users, scores or purchases were copied into authoritative state.
- Ranking supports only the existing Wealth/Charm weekly/monthly data. Gift/Active/Daily combinations show unavailable. Recharge displays actual configured packages rather than fabricating the six prototype amounts when packages are absent.
- Levels lack authoritative XP totals/next-level progress; SVIP lacks total-recharge progress. These values are not invented.
- Privacy, language and notification preferences remain static/unavailable because their persistence/localization contracts were outside this UI-only scope. English/Arabic choices do not implement app-wide RTL or translation.
- Me's latest-three gift-ranking cards, final Add Friend action, visitor timestamps, and room rewards/support/certification/activity/banner services remain incomplete. Room Member shows known seat profiles, not a full participant directory.
- Moment comments retain the existing page flow rather than the prototype sheet. Existing extra chat/CP invitation flows remain accessible.
- VIP emblems are generated from the HTML SVG geometry, with text converted to font outlines for Flutter SVG compatibility. Float/halo/sparkles are implemented; exact rays, shimmer, every animated frame/mic/theme treatment and game wheel animation are not fully reproduced.
- Auth decoration/brand marks and several profile/medal rails have visual differences. Honor Wall artwork is a catalog presentation, not fabricated ownership.
- Native Android/iOS builds and device screenshots were not verified in this environment. Widget screenshots verify selected surfaces, not every possible live-data state.

## Validation

- Flutter analyzer: no issues.
- Full regression suite: 115 tests, including seven compact game boards, live-flow retries/drafts/gift contracts/logout/reconnect, VIP tier selection, CP layout and overlays with larger text.
- Room regression asserts exactly ten seat circles in two aligned rows of five at 320×640.
- Golden snapshots: Home, Fruit Party Jackpot, Grady Pro, Slot Jackpots, Lucky Wheel 77, VIP, SVIP, Treasure and Crystal.
- Reference HTML SHA-256: `f3401ddc3d565428a07697a5f21e416ef5e34329450e6eda78b149e425bbf4e2` (428560 bytes), unchanged.
- All 27 newly extracted room-tool/gem/chest/crystal/medal/prize images compare byte-for-byte with embedded HTML assets.
- Independent review found room-avatar regression, long CP-name overflow and missing Account UI; all three were corrected.
- Scope audit: presentation Dart, reference assets/fonts, pubspec asset/font registrations, UI tests/goldens and this report only. No repository/data layer, backend, migrations, game engine, Vivox or native files changed.

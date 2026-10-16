# Nimzo fresh UI rebuild — 7 October 2026

Yeh implementation checkpoint hai; A-to-Z completion ya release readiness ka claim nahi.

## Source aur preservation

- Working branch: `feature/profile-reference-redesign`.
- Base/reference: `de425c1b6399af0c0952959fd38b52d2b563ed82`.
- `nimzo-ui-1.html` ka CSS, navigation, screens, actions aur embedded artwork inspect kiya. Latest uploaded master instructions source priority hain.
- Deleted Flutter presentation Git history se restore nahi ki. Existing repositories, models, Supabase Auth, RPCs aur Vivox service reuse ki.
- Koi live SQL nahi chalaya; users, permanent IDs, rooms, balances, ledger ya social data reset/delete nahi kiya.
- HTML ke sample users, balances, engagement, round timers aur random financial results production mein copy nahi kiye.

## Files aur implementation

- `nimzo/lib/core/theme/app_theme.dart`: current purple/pink tokens, fields, cards aur typography.
- `nimzo/lib/core/widgets/reference_widgets.dart`: avatars, real empty/loading/error/retry states.
- `nimzo/lib/app/shell.dart`, `router.dart`: Home/Games/Moments/Messages/Me, private feature routes; production navigation se admin route remove.
- `nimzo/lib/features/auth/presentation/*`: email login/signup, Google/Facebook launch, forgot/reset password aur verification presentation.
- `nimzo/lib/features/profile/*`: Me/public profile, editing, gallery/camera upload, levels, real gifts/stats/collections/CP relationship.
- `nimzo/lib/features/home/home_screen.dart`: real popular/followed/recent rooms, country filter, existing owned room reuse.
- `nimzo/lib/features/rooms/presentation/*`: create/open room, 5+5 seats, server-backed seating, Vivox service, chat, gift/game entry, settings, private password prompt.
- `room_session.dart`: pending DB/voice join ke dauran close aur duplicate close coordination; disposed WidgetRef ko async use nahi karta.
- `nimzo/lib/features/gifts/gift_sheet.dart`: server-authoritative gift requests, confirmation aur stable retry key, successful send par wallet/sender/recipient refresh.
- `nimzo/lib/features/games/*`: approved seven-game catalog/boards; unverified betting/results disabled. Existing two legacy RPC contracts test/caller compatibility ke liye retained, visible catalog mein extra games nahi.
- `nimzo/lib/features/messages/messages_screen.dart`: conversations aur realtime private messages.
- `nimzo/lib/features/moments/moments_screen.dart`: feed, detail, comments, likes, post creation/edit/image replacement.
- `nimzo/lib/features/social/social_screens.dart`: following/followers/visitors, CP request/search/send/accept/decline/cancel.
- `nimzo/lib/features/discover/ranking_screen.dart`: existing leaderboard RPC.
- `nimzo/lib/features/wallet`, `recharge`, `vip`, `notifications`, `settings`: real balance/catalog/status/events; unverified purchase/service states clearly unavailable.
- `supabase_provider.dart`: auth identity follows session events; data repositories rebuild on account transitions.
- Realtime room/message/gift stream families auto-dispose when no screen owns them.
- `tools/extract_reference_assets.py`: 93 original images extract karta hai; prototype pricing/data import nahi karta.
- `nimzo/assets/reference/*`: exact approved images, integrity test byte-for-byte match karta hai.
- `nimzo/test/*`: existing tests retained, focused lifecycle/identity/setup/error/game-layout tests add kiye. Existing source/tests ki formatting normalize ki.
- `.github/workflows/nimzo-apk-build.yml`: checks ke baad Android verification APK build, packaged Vivox/OAuth checks, SHA256 aur prerelease testing download publish karta hai. Testing build final release certification nahi hai.

## Verification

- Flutter 3.47.6 / Dart 3.13.5 use kiya.
- Full Flutter suite: 77 tests pass at the latest continuation checkpoint.
- Native Vivox contract: 2 tests pass.
- Voice-token authorization: 6 tests pass.
- Reference artwork integrity: 1 test pass, 93 assets matched.
- Small-phone game layouts: 7 games at 320 × 640, no overflow.
- Home + four game render regression baselines generated aur inspect kiye. Yeh HTML pixel parity ka proof nahi; remaining screens ka comparison baqi hai.
- `dart format` aur `git diff --check` run kiye.

## Baqi kaam aur blockers

1. Live Supabase access/test account/device is session mein available nahi. Migrations ko live-applied nahi maana. RLS, Storage policies, production catalogs, room uniqueness/ID triggers aur economy config live read-only verify karna baqi hai.
2. Seven approved game UIs ka verified server service repo mein nahi. Existing `fruit_party` aur `fruit_wheel` contracts approved boards se different hain. Client random outcomes/payouts use nahi kiye. Production betting unavailable hai.
3. Actual Google/Facebook callbacks aur email/signup/session restore physical device par test karna baqi hai. Email signup confirmation UX abhi basic hai.
4. Vivox native service aur bridge reused/tested contracts hain; two-device incoming/outgoing audio, interruptions, reconnect/background mic behavior runtime verify nahi hua.
5. Full HTML visual parity abhi complete nahi: gift animations, assigned-moderator/ban coverage, several sheets/catalog sections aur all-screen responsive captures polish baqi hai. Profile cover/avatar overlap aur owner mute/kick sheet ab implemented/tested hain.
6. VIP/SVIP live pricing/duration, Sunday reward scheduler aur purchase contracts verify nahi. Existing Friday-named catalog ko current scheduler ka proof nahi maana.
7. Store/Tasks/Privacy/Help/deletion aur payment gateways ka verified production implementation missing/unverified hai; unavailable states show hain. Recharge receipt verifier reuse hua, store checkout UI abhi unavailable.
8. Moments pagination, unread list details, notification preferences aur several public-profile social actions abhi incomplete hain.
9. Android SDK/device aur macOS/iOS runtime available nahi. iOS Vivox native bridge/project readiness verify nahi; Android testing build GitHub CI par pass hua; iOS build/device verification abhi nahi hua.
10. Owned closed room reopen contract ki zaroorat investigate karni hai; duplicate room creation intentionally avoid hoti hai.

Agla checkpoint: remaining reference presentation aur supported interactions finish, live backend/device QA, phir full retest aur final release APK. Yeh source checkpoint installable final APK nahi.


## Latest continuation — safe branch publish and verification APK

- Local `5b7c2fccec2d5f006bd754ec85e7f54f72f0376b` tree GitHub commit `eae09c81d064201423a7927498ec74ab3e941016` mein exact match ke saath publish hua. API commit metadata ki wajah se SHA alag hai; source tree same hai.
- Compatible live gift names approved `assets/reference/gift/` art use karte hain. Unmatched art unavailable hai; generic gift icon inventory remove hui. Live IDs/prices unchanged.
- Quantity 1/10/99, confirmation mein total, duplicate confirmation guard aur uncertain-response retry mein frozen gift/quantity/key implemented. Quantity/client price financial authority nahi; RPC decides settlement.
- Profile/room/Moment gifting existing RPCs reuse karta hai. Successful send wallet, sender/recipient profile stats aur room lifetime total refresh karta hai.
- Moment feed real author avatar path use karta hai.
- Room header real room artwork aur lifetime coins use karta hai. Room settings gallery/camera uploads owner room UUID folder mein save karte hain; Storage policy still authoritative.
- Shared image upload validates JPEG/PNG/WebP signature, preserves MIME/extension, limits upload to 10 MB, and uses authenticated ownership folder. No production upload was made by development tests.
- Latest local checks: 70 Flutter tests pass; analyzer no issues; 2 native contract tests, 6 voice authorization tests, 1 reference integrity test pass; format and whitespace check pass.
- CI build now produces a prerelease testing APK with a SHA256 companion only after tests and packaged-native verification succeed. Actual build/download result is recorded after CI finishes; do not assume it has succeeded from this source checkpoint.
- No destructive production operation, data reset or old deleted UI restoration occurred. Pending engines/payment/device QA/visual parity/iOS gaps listed above remain release blockers.


## Latest UI/interactions continuation

- Room occupied-seat tap now opens a real profile sheet: full profile, follow/unfollow, friend request/accept, gift. Owner sees server-backed mute/kick with removal confirmation; self seat offers leave and self gifting. Locked occupied seats still allow opening the sheet. Existing RPC/RLS remains authoritative; assigned moderator/ban coverage is not claimed.
- Seat leave captures its services before async work so dismissing the sheet cannot abandon the requested operation. If mic disable fails after server seat removal, voice disconnect is attempted. Two-device runtime audio still requires QA.
- Public profile uses the reference 130px cover and 78px avatar with actual overlap. A geometry regression test verifies overlap; this is not full HTML pixel parity certification.
- Conversations use current profile names/real avatar paths with server message preview. Completing a send after leaving the screen no longer clears a disposed controller.
- Own Moment deletion is an explicit confirmation action; repository filters by authenticated author and requires a returned deleted row. Cancellation/confirmation behavior is tested with a recorder; no production post was deleted by these tests.
- Reference cards now have a Material surface so ListTile ink/background is not hidden by decoration. Existing render baselines and full tests remain passing.
- Latest local verification: **77 Flutter tests passed; analyzer no issues; 2 native contract tests, 6 token authorization tests, 1 reference asset integrity test passed.** Format and whitespace checks passed.
- First verification APK was actually built/uploaded for `73b8558b513c99e5f974ee493dcc7851c7a3482a`, release tag `nimzo-reference-test-73b8558b513c`; APK SHA256 `13f63a5d1a1ce351216daa51545ec86481bfff2d933f86ad83a09bb6bca8fa50`. Newer UI source in this checkpoint requires its own CI build; use the later commit's artifact once verified.
- These APKs are prerelease testing builds. Final release certification remains blocked by verified seven-game settlement services, payment/store credentials/contracts, complete visual parity, physical-device OAuth/audio QA, stable production signing and iOS readiness. Do not label this A-to-Z complete.


## 2026-10-08 — Moment comment interaction batch

- Continued from remote ccd8d16 (eae09c8 is an earlier ancestor); completed rebuilds were preserved.
- Comment submission captures repository/container before awaiting. Completion after screen dismissal refreshes data without touching disposed controller/ref.
- Successful comments refresh detail/comments, feed and author profile Moments; server counts remain authoritative. A newer draft typed while sending is preserved. Existing send busy guard and backend insert flow are preserved.
- Two delayed-response widget regressions cover navigation away and newer draft/cache refresh. Full Flutter suite: 79 passed. Analyzer: no issues. Format and whitespace checks passed. No production mutation was performed.
- Next manageable batch: Moment like duplicate-tap/lifecycle handling and create/edit success cache refresh, with focused regressions. Existing visual presentation remains unchanged by this batch.


## 2026-10-08 — continuation from e740a328

- Pulled the actual remote e740a328 checkpoint; prior Moments like/cache fixes and approved current UI preserved. No old audit/rebuild repeated.
- Stable checkpoint 56a4c73c07f3fb863a84da4c99e96a5df26b94b0 published: failed Moment editor loads now offer retry; initial Vivox mute failure rejects join and leaves native channel.
- Moment editor now offers Gallery/Camera selection, actual uploaded photo preview and removal from draft; removal does not delete Storage files. Save completion after dismissal refreshes feed/detail/profile via captured container; post text/image are captured before awaiting.
- Direct messages preserve a newer draft typed during an earlier pending send. Existing server send/read contracts remain unchanged.
- Room voice disconnect offers Retry voice, clears local mic state and reconnects without rejoining membership. Mic toggles have a pending guard and stable requested state. Seat revoke/mute attempts mic disable; on failure it leaves voice.
- Room chat prevents simultaneous duplicate sends and preserves a newer draft. Ephemeral timestamp/filter and room-session membership flow retained.
- Native voice errors clear stale speaking indicators. These are Dart/native contract verifications, not physical audio certification.
- Regression: flutter pub get --offline passed using locked verified cache; dart format . passed; analyzer no issues; full 86 Flutter tests passed (including reference render/small-phone game tests); 2 native contract tests, 6 voice-token authorization tests and reference integrity test (93 exact images) passed; git diff --check passed.
- No production data mutation/migration, payment, secret access or old deleted UI restoration performed. No fake financial results or users added.
- App is not certified release-ready. Remaining implementation includes seven approved game settlement services (unsupported betting remains unavailable), payment/store/VIP production contracts, comprehensive HTML parity and unfinished supporting/social/message interactions. Separate external blockers: existing production signing key/configuration, physical-device OAuth and two-device Vivox audio/reconnect/background QA, iOS native/build/device environment. Existing automatic workflow can publish testing APKs; such builds do not certify these gaps.
- Next code batch: authenticated Moment update row confirmation, remaining editor/empty/error responsive coverage, real comment-author identity, room moderation/permissions coverage and unread behavior supported by verified server contracts. Do not repeat already completed foundation or like/cache fixes.


## 2026-10-08 — notification/social/message continuation from d67e6e6

- Preserved current approved UI and completed rebuild/Moments/room work; no old audit or production mutation.
- Checkpoint 093bfab31c7a0694ec872e199e51489ddcf8ae47 published after 93 Flutter tests and clean analyzer.
- Notifications: existing real category query and mark_notifications_read RPC exposed with filters, pending guard, retryable failure and pull-to-refresh. Read styling uses server read_at. No fabricated notifications/counts.
- Followers/following/visitor lists display stored avatar paths. Conversation header displays actual recipient identity/avatar and opens their profile.
- Logout captures services before awaiting and still attempts session logout when native voice leave fails. Existing server room-cleanup/account retention flows preserved.
- Moment edits require an authenticated-author filtered returned row; zero affected rows no longer report saved. Comment rows display real author name/avatar and profile navigation; 320x640 layout regression passes.
- Home refresh waits for the currently selected followed/recent backend list, instead of only the popular list.
- Conversation unread badges use verified conversation_list unread field. Successful mark_read refreshes server counts; overlapping mark-read calls are guarded and only incoming unread rows trigger them. Composer max length matches verified send_message server limit of 1000 characters.
- Final source verification: flutter pub get --offline succeeded with verified locked cache; dart format . clean; flutter analyze no issues; 94 Flutter tests passed including game/render/responsive regressions; 6 voice-token authorization tests passed; 2 native contract tests passed; reference integrity test passed with 93 artwork matches; git diff --check passed.
- Final APK must be built from this latest published source and verified independently. This source status does not assume CI success. Existing workflow publishes release-mode testing APKs using generated template debug signing, not a certified production signing identity.
- Full A-to-Z certification is not claimed. Remaining implementation includes comprehensive HTML parity, seven approved games' verified settlement services (unsupported financial controls remain unavailable), payment/store/tasks/VIP production integration and unfinished supporting interactions. External requirements remain production signing credentials, real-device OAuth and two-device Vivox/background audio QA, and iOS native/runtime environment. These implementation gaps are not being misrepresented as credential/device-only blockers.

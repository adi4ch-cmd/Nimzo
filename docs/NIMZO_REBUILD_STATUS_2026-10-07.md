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
- Full Flutter suite: 70 tests pass at the latest continuation checkpoint.
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
5. Full HTML visual parity abhi complete nahi: profile cover/avatar overlap, gift animations, room moderator actions, several sheets/catalog sections aur all-screen responsive captures polish baqi hai.
6. VIP/SVIP live pricing/duration, Sunday reward scheduler aur purchase contracts verify nahi. Existing Friday-named catalog ko current scheduler ka proof nahi maana.
7. Store/Tasks/Privacy/Help/deletion aur payment gateways ka verified production implementation missing/unverified hai; unavailable states show hain. Recharge receipt verifier reuse hua, store checkout UI abhi unavailable.
8. Moments delete/pagination, message avatars/unread list details, notification preferences aur several public-profile social actions abhi incomplete hain.
9. Android SDK/device aur macOS/iOS runtime available nahi. iOS Vivox native bridge/project readiness verify nahi; APK/iOS build nahi banaya.
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

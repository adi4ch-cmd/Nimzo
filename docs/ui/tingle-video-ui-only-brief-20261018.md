# NIMZO — Tingle full-video UI-only reference and acceptance brief

Status: **visual rebuild in progress; not accepted as pixel-perfect**.

## Locked owner requirements (2026-10-18)

- Primary full-video reference: https://drive.google.com/file/d/1YQ1eqKObPVsQ6YrWDKlNppu_1xoP2Z6l/view?usp=drivesdk
- Prior XAPK reference: https://drive.google.com/file/d/1_F0rUS1S4enrM9-3heyy6Loa7qvi02DC/view?usp=drivesdk
- Existing 23 reference screenshots and visual inventory: `docs/ui/tingle-ui-first-reference-map-20261017.md`.
- **Login screen must offer exactly three login methods: Email + Facebook + Google.**
  Do **not** show Mobile/Phone/OTP or unsupported Quick Login options. Email registration and password reset remain as separate email-account flows.
- Existing Supabase auth controller already implements `.facebook()`, `.google()` and email sign-in. Preserve those contracts; do not rewrite the OAuth/backend setup.
- **Only Flutter UI and presentation/navigation changes are authorized.** Do not touch Supabase schema, RLS, Edge Functions, RPCs, data migrations, auth backend, token settings, coins, diamonds, wallet settlement, user records, existing Vivox audio integration, game logic, or economy.
- **Backend work is prohibited until the owner explicitly approves after UI review/testing**, even if other tests succeed.
- Preserve NIMZO branding and only original or properly licensed art, ten mic seats in 5x2, audio-only app, package identity `io.nimzo.app`.
- Do not merge, perform production release, or claim exact visual parity before owner review.

## Exact work to hand to Codex

1. Retrieve the video from the Google Drive link. The link's accessible bytes have not yet been independently verified in this ChatGPT environment. If access is denied, report the error and ask for a directly accessible video file.
2. Inspect the entire video, pausing at every distinctive screen, tab, tap, popup, menu, gift panel, animation, scroll position and state. Use video-frame extraction (FFmpeg) and timestamped contact sheets where available.
3. Create a timestamp-to-screen inventory: screen name, opening/closing time, icons, text, typography, backgrounds, gradients, measurements, navigation paths, modals, loading/empty/populated states. Cross-reference the 23 supplied screenshots.
4. Compare each screen with the current Flutter implementation. Make actual UI edits for every observed discrepancy, not just an audit or vague redesign. Preserve safe pre-existing actions; do not display fabricated balances, entitlements, prices, users, rewards or working actions.
5. Login: ensure `nimzo/lib/features/auth/presentation/tingle_login_screen.dart` shows Email, Facebook and Google; Facebook invokes the existing `authControllerProvider.notifier.facebook()`. Do not re-expose `/phone-login` or Quick Log In.
6. Screen groups: auth/profile setup; Home/search/country filter/room cards/navigation; room with ten 5x2 seats, in-room menus/mini profiles, tools, reactions/music/exit; My Profile/public profile/edit/friends/levels/CP; Moments/create/post; Messages; Store/medals/membership previews; coins/check-in/tasks/settings/help; every additional observed surface.
7. Compare reference and NIMZO screenshots at matching viewport and text scale when device screenshots are available. Also test 320dp, 360dp and 390dp layouts and interactive widget states. Log every unverified pixel/icon difference.
8. Existing Codex environment reported no ADB device/emulator, Flutter SDK or /dev/kvm. **Do not stall** waiting for unavailable emulator. Use static image analysis and repository changes, then GitHub Actions for Flutter analyze, widget tests and Android test-APK compilation. Mark physical-device screenshot parity as unverified until the owner supplies screenshots or a real device is used.
9. Commit small coherent source changes to the UI feature branch, do not touch backend/games, and provide the changed files, test results, commit SHA, user-review checklist and test APK link when requested.

## Acceptance checklist per surface

| Evidence | Check |
|---|---|
| Reference video | Timestamp and extracted frame available |
| Screen | Widget layout matches geometry and hierarchy |
| Artwork | Matching original/permissioned icon sizes, style, opacity and placement |
| Motion | Visible and testable transitions where observed |
| Controls | Every visible tappable control, back action, modal, scroll, overlay |
| Layout | 320/360/390dp, keyboard, overflow, safe area |
| State | Empty/loading/error/data, no invented backend content |
| Risk | No changes to backend, game logic or stored user data |
| Review | Owner/device comparison, remaining differences explicitly listed |

**Never claim completion from an analyzer pass or a test APK alone.** The owner explicitly rejected previous approximate UI builds and requires observed visual match first.

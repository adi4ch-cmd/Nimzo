# Nimzo rooms and gifts audit — 2026-10-19

Release source: `feature/profile-reference-redesign` (`f1140e5`). Project: `kvqvlpozqokwarovwmwv`. The GitHub default branch contains an older application; these repairs target the documented APK source branch.

## Confirmed problems repaired

- Rocket progress listened to `gift_events`, whose authenticated SELECT permission was revoked. It now listens to the settlement-created, RLS-scoped `gift_animation_events` stream. Progress and podium still come from authoritative RPCs; blast animations still require verified milestone events.
- A live Moment image existed only in the old `moment-images` bucket, but the app requested `moments` and received 400 responses. Photos now retry the legacy bucket and terminate with a visible unavailable message if neither object exists. User posts and storage objects were preserved.
- Daily room gift task queried private financial receipts and silently lost its completion state. `my_daily_room_gift_status()` returns only the active caller's UTC-day boolean, including after leaving the room. The public facade is SECURITY INVOKER; the private implementation checks authentication and account status. Financial receipt access remains revoked.
- Room gift entry points still said “Send Car” after four premium gifts became active. They now identify the full gift action, and existing seat/room interaction tests pass.
- Asset and walkthrough test fixtures referenced retired gifts, renamed game IDs and removed ranking tabs. Updated those fixtures to the current supported assets/catalog/navigation.
- Committed the missing WebView dependency lock entries. Existing dependency declarations were preserved.

## Live database verification

`supabase/tests/rooms_gifts_repair.sql` passed under the authenticated role in both open rooms: self-gift coin debit and 45% diamond credit, readable verified animation event, exact Rocket progress delta, idempotent replay without double counting, and task completion after room exit. All mutations rolled back.

All five active catalog gifts settled in the funded account: Sports Car, Hall of Fame, Dragon Throne, Ice Fire Phoenix and Holy Tiger. The lower-balance account correctly rejected the expensive gifts with insufficient coins. Tests did not grant coins or persist purchases.

Authenticated reads passed for rooms, profiles, conversations, settings, moments, PK board, game history, family directory and all six supported wealth/charm/room weekly/monthly ranking combinations. Unsupported daily rankings correctly reject requests and are already presented as unavailable in the UI.

All four private premium video/thumbnail pairs exist in private Storage. All twelve bundled Rocket VAP clips passed the repository SHA-256 verifier. The historical Moment JPEG was fetched successfully from its original public bucket.

## Application checks

- 33 focused room/gift/Rocket/Moment/task tests passed.
- 8 repaired asset/catalog/phone-walkthrough fixture tests passed.
- Voice-token authorization tests: 8 passed.
- Android/Firebase/release tooling unit tests: 12 passed.
- Flutter analyzer: no errors or warnings; existing informational style lints remain.
- Fresh independent code review: no Critical or Important findings.

The initial complete Flutter suite had 351 passes and 14 failures. Six room/gift label failures and five obsolete fixture failures were corrected and rerun successfully. Three pre-existing visual test groups remain unresolved:

1. `master_visual_preview_test.dart` — old Treasure snapshot.
2. `reference_preview_test.dart` — old Home/game snapshots and legacy `fruit_party_jackpot` / `slot` fixtures.
3. `remaining_visual_qa_test.dart` — old catalog snapshot.

Old golden images were not regenerated merely to turn failing comparisons green. This branch is a draft repair pending visual-baseline reconciliation and an APK release/device test. A complete “everything active” claim is not supported.

## Remaining limitations

- New APK changes require merging into the documented release source and building/installing an update. The new daily-status RPC is already live.
- Native microphone/audio and private VAP playback were not verified on a physical device; authorization/unit/media-integrity checks passed.
- Inactive retired or staged gifts without approved playable media were not advertised as sendable. No substitute media or approval flags were fabricated.
- Supabase advisors still report existing intentional privileged RPCs, private tables without public policies, and [disabled leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No new advisor finding was introduced by the caller-status facade. Existing RPC exposure is documented by the [Supabase advisor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Review minors deferred: add an RPC-failure task test and assert the realtime server-filter arguments in its network fake. The production code retains both server and payload room filtering; RPC failures preserve unknown task status.

> Historical checkpoint. The newer [issue 15 implementation and verification report](../issue-15-review/verification.md) supersedes its remaining-work/APK status.

# UI continuation verification — 2026-10-17

This is a committed UI checkpoint, **not** a complete Tingle reconstruction,
pixel-perfect certificate, Phase 3 approval request or release. Backend remains
out of scope. The next work is continued visual correction, not backend work.

## Evidence

- Full 1,128,636,234-byte video retrieved and read by FFmpeg; duration 385.626822s.
- 1,543 quarter-second frame samples plus 541 scene-change candidates, indexed
  locally in `/workspace/reference/index.json`.
- [Timestamp inventory](screen-inventory.md) covers the recording including its
  last 383–385s profile dismissal/room animation states.
- [Preview gallery](preview.html) and [overview](previews/overview.jpg): 13
  headless Flutter screen/dialog renders. Captures use fixture identity and
  empty/unavailable data, at 360×800 logical pixels exported at 3×. Gallery
  WebP copies are 720×1600. Main-tab captures show screen content separately
  from MainShell; bottom navigation is implemented in `app/shell.dart`.
- No physical Android device screenshot comparison has been performed.
- Existing 23 source screenshots were absent locally; their committed map was
  consulted. Previous NIMZO goldens are not Tingle parity evidence.

## Commands and observed results

Flutter stable 3.47.7, Dart 3.13.5, Linux headless Flutter test renderer.

| Command (from `nimzo/`) | Result |
|---|---|
| `flutter analyze --no-pub --no-fatal-infos` | Exit 0; no errors/warnings; 39 informational style lints |
| `flutter test --no-pub --reporter expanded` | **324 passed, 3 failed** |
| Focused login/membership/room/mini-profile/Store/Friends/country/narrow layout run | 28 passed before review fixes |
| `flutter test --no-pub test/tingle_video_ui_test.dart test/tingle_friends_screen_test.dart` with capture define | 5 passed after review fixes |
| `flutter test --no-pub test/tingle_video_ui_test.dart test/login_methods_ui_test.dart` with capture define | 6 passed after final social icon correction |
| `python -m py_compile tools/ui/extract_tingle_reference.py`; extractor `--help` (repo root) | Passed |
| `git diff --check` | Passed |

The new walkthrough tests exercise **320, 360 and 390dp** across login, Home,
Party, Moments, Messages, My Profile, Profile Details, room creation, Friends,
Family unavailable state, membership and Store category preview. They also test
sixth-tier selection, privilege modal navigation/dismissal, terms opening/back,
search opening/filtering/closing and the fixed Save button during profile scroll.
These are layout/interaction checks; they do not prove a visual match.

### Remaining failing suites

- `reference_preview_test.dart`: previous Home/game-board golden snapshots.
- `master_visual_preview_test.dart`: Treasure overlay golden.
- `remaining_visual_qa_test.dart`: previous Catalog golden.

These are the same suites documented as unresolved in the prior branch
checkpoint. Their baselines were **not** regenerated or assertions disabled.
The full test run is therefore **not green**. Detailed local output:
`/workspace/reference/tests-verified.log`, and Flutter feedback in
`nimzo/test/failures/`.

## Independent review and corrective checks

A separate code reviewer inspected the presentation diff. Three actionable
regressions were reproduced with failing tests and fixed:

1. Closing inbox search now clears the query, so an invisible filter cannot hide
   conversations. The walkthrough test checks the returned empty-inbox state.
2. Friends search now includes the displayed numeric NIMZO ID. A populated
   fixture test verifies numeric-ID lookup rather than internal UUID lookup.
3. Normal VIP is accessible again through the profile menu; the walkthrough
   test scrolls to and checks the preserved VIP entry.

Other fixes found by rendering/testing: registration prompt wraps at small
widths; profile Save stays visible during scrolling; shortcut icons restored;
Google/Facebook use the existing full-color SVG marks; login field/forgot-button
geometry tightened after side-by-side frame inspection. No quantitative
whole-screen parity score is asserted because account data, supported methods
and artwork intentionally differ.

## Still open before full UI acceptance

- Original premium artwork remains an approximation: 3D SVIP crests, CP reward
  frames, family backdrop, room entrance effects, mascots and advertising art.
- Populated Party/Family screens cannot be reproduced by fabricating people,
  memberships or banners. Party uses real existing room reads; Family explicitly
  remains unavailable without changing backend services.
- Multi-image Moments, Online-only inbox presence, every profile deep tab and
  every popup/motion timing are not certified against the reference.
- Host screenshot fonts lack some emoji flag glyphs; Android emoji rendering,
  system bars, keyboard/IME, native media picker and device text scale still need
  matching-device verification.
- Three legacy golden failures remain visible, and fine spacing/icon/timing
  mismatches remain. Owner visual acceptance has **not** occurred.

## Scope boundary

Verified no changed source paths under `supabase/`, `nimzo/supabase/`,
`features/games/`, `features/wallet/` or `features/voice/`, and no changed
`auth_controller.dart`, auth repository, package identity or dependency files.
Navigation now exposes Party and the Family unavailable screen; the existing
Games catalog/game routes remain reachable. Existing purchase, gift, moderation,
profile-save, auth and voice calls are preserved. Preview controls never purchase
or grant memberships. Ten microphone seats remain 5×2.

No APK/AAB was built, no release workflow was dispatched, and no deployment,
merge, backend migration or production change was performed. Push-triggered APK
workflows were inspected: this branch's APK jobs only trigger when their own
workflow files change; none of those files were edited.

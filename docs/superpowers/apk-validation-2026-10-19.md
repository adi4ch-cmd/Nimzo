# APK follow-up: Nimzo 1.0.31 (131)

The three previously failing visual test groups were reproduced and repaired:

- Reference game IDs now follow the current catalog. Lucky 77, Grady Lion and Jackpot use native WebViews, so widget tests register a test platform and verify asset handoff, loading/error states, bridge restrictions and navigation. Native placeholders are never accepted as screenshots of game graphics. Six dedicated native host tests pass.
- The level-collection walkthrough scrolls to each unique level range; color names can also occur in the profile header and are not unique lazy-list targets.
- Treasure artwork is decoded before its screenshot is captured. Removed an obsolete attempt to decode retired medal-store artwork.
- Ranking tiles now have a Material surface above their decorated backgrounds, fixing Flutter's hidden tap-feedback assertion.

Reviewed the 29 updated Flutter screenshots in a contact sheet: no error overlays or clipped layouts were accepted. Comparisons remain enabled for real Flutter surfaces, including three newly covered game boards. The three visual groups and six native-host tests then passed without `--update-goldens` (9/9). Existing game-service-unavailable and development-preview states are displayed honestly; these tests do not enable real-money games.

The Android workflow builds the exact dispatched SHA, preserves the lockfile, includes Firebase and the real Vivox SDK/JNI bridge, and verifies all twelve Rocket videos. It runs Flutter and backend authorization tests before compiling. The release-mode APK uses a development signing certificate; it is a test APK, not a store/update-channel release. APK package/signature/native/media/FCM checks and Android emulator installation/startup must succeed before its artifact is uploaded.

This follow-up supersedes the three unresolved visual groups in `backend-repair-validation-2026-10-19.md`. Final full-suite and APK verification outcomes are recorded after execution.

## Completed source checks

- Full Flutter suite: **375/375 passed**, including all three previously failing visual groups.
- Backend function tests: **32/32 passed**.
- Android/Firebase/release tooling tests: **12/12 passed**.
- Flutter analysis: no errors or warnings; 48 existing informational style notices.
- Independent review: no Critical or Important findings.
- Chromium execution of the real Lucky 77, Grady Lion and Jackpot HTML: all three passed asset rendering and local practice interactions; no JavaScript errors or mutating network requests. Lucky 77 exclusive-choice and bridge handling, Grady placement/clear, and Jackpot line-total/spin completion were exercised. Screenshots inspected. These are browser checks of bundled HTML, separate from the Android emulator launch test.

## Moments photo reference follow-up

The user supplied a two-photo feed reference during the first successful APK build. The final APK includes a new photo grid: one large4:3 preview, two equal square photos side by side, or three-column grids for up to nine photos;6px gaps and10px rounded corners. Post content aligns with the author column. Tapping a tile opens the original image in a full-screen zoom/swipe viewer; crop-free originals and legacy-bucket fallback remain available.

Nine new layout/viewer tests passed at320dp and390dp, with17 related Moment tests passing overall. The intermediate1.0.30(130) APK passed package/native/media checks and Android emulator launch; it is not the final delivery because it predates the requested photo change. The final deliverable is1.0.31(131).

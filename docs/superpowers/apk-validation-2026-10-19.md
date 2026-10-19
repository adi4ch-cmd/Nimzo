# APK follow-up: Nimzo 1.0.30 (130)

The three previously failing visual test groups were reproduced and repaired:

- Reference game IDs now follow the current catalog. Lucky 77, Grady Lion and Jackpot use native WebViews, so widget tests register a test platform and verify asset handoff, loading/error states, bridge restrictions and navigation. Native placeholders are never accepted as screenshots of game graphics. Six dedicated native host tests pass.
- The level-collection walkthrough scrolls to each unique level range; color names can also occur in the profile header and are not unique lazy-list targets.
- Treasure artwork is decoded before its screenshot is captured. Removed an obsolete attempt to decode retired medal-store artwork.
- Ranking tiles now have a Material surface above their decorated backgrounds, fixing Flutter's hidden tap-feedback assertion.

Reviewed the 29 updated Flutter screenshots in a contact sheet: no error overlays or clipped layouts were accepted. Comparisons remain enabled for real Flutter surfaces, including three newly covered game boards. The three visual groups and six native-host tests then passed without `--update-goldens` (9/9). Existing game-service-unavailable and development-preview states are displayed honestly; these tests do not enable real-money games.

The Android workflow builds the exact dispatched SHA, preserves the lockfile, includes Firebase and the real Vivox SDK/JNI bridge, and verifies all twelve Rocket videos. It runs Flutter and backend authorization tests before compiling. The release-mode APK uses a development signing certificate; it is a test APK, not a store/update-channel release. APK package/signature/native/media/FCM checks and Android emulator installation/startup must succeed before its artifact is uploaded.

This follow-up supersedes the three unresolved visual groups in `backend-repair-validation-2026-10-19.md`. Final full-suite and APK verification outcomes are recorded after execution.

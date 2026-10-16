# Final completion implementation plan

User-directed inline execution: continue current approved implementation, preserve all data/designs, repair verified failures, push branch and produce installable test APK. No new game/economy rules are authorized by visual references.

1. Reproduce native teardown failure with a Flutter regression: a shutdown exception must clear speaking state and permit a fresh initialized retry. Fix `VivoxVoiceService._leave` with guaranteed local cleanup and preserve native errors.
2. Reproduce release delivery failure using workflow contract tests. Replace unsigned-only fallback with a release-mode test APK using Android development signing; verify its signature/package/native contracts and upload it under a test-only name. Skip permanent publication when secrets are absent; reject partial signing configurations. Preserve permanent certificate enforcement and updater publication.
3. Inspect live metadata for permanent-room constraints, gift/auth/storage contracts and pending migration prerequisites. Apply only safe, tested repairs supported by verified evidence; never invent game settlement rules or level thresholds.
4. Run dependency resolution, formatting, strict analyzer, full Flutter suite, native/Edge/tool checks. Commit changes by concern and push `feature/profile-reference-redesign`; observe CI and independently inspect the resulting artifact.

Review focus: shutdown errors, stale speaking indicators, incomplete signing secrets, permanent certificate mismatch, test APK accidentally entering the updater. Physical voice/OAuth/purchases remain device/provider checks.

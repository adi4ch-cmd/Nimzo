# Nimzo completion audit and APK

**Goal:** Verify the latest Nimzo branch against live Supabase and deliver an installable Android build.

**Baseline:** fix/remove-vip-svip-all-20261016 at 7650237; main is obsolete. Preserve the deployed VIP/SVIP retirement and existing user balances.

**Approach:** Use the existing Flutter, native, release and backend checks. Repair demonstrated failures without inventing reward economics or provider credentials.

- [x] Locate the latest code and matching Supabase project.
- [x] Verify RLS, safe views, Realtime publication, storage and retired memberships.
- [x] Cover current Flutter templates missing the applied Kotlin plugin in tools/tests/android_gradle_compatibility_test.py, observe failure, and repair tools/configure_android_gradle.py idempotently.
- [x] Repair and verify live private profile API entry points and the concurrently enabled self-profile gift wallet count.
- [x] Run complete Flutter tests, native/update checks, server authorization checks and asset integrity checks.
- [x] Generate Android platform, install the verified Vivox SDK, build APK and verify its package/signature/native libraries.
- [x] Record audit findings and remaining provider/device prerequisites; deliver the actual APK with checksum. GitHub binary upload returned HTTP 401, so the verified APK is provided in shared downloads.

**Review focus:** Kotlin compilation with AGP 8; idempotent project configuration; unchanged dependency lockfile; native voice libraries included; test signing clearly identified and kept out of production updater publication.

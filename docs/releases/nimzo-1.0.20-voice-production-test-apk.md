# NIMZO Android 1.0.20+120 — requested test APK

- Source branch: `feature/profile-reference-redesign`.
- Approved Vivox Production server, domain and issuer are pinned server-side in the `voice-token` Edge Function; its latest deployment is version 7.
- The Vivox signing secret stays in Supabase secrets. It is not embedded in the app or repository.
- Live device-side Vivox authentication and microphone/room audio remain **unverified**. Error 20122 must not be reported fixed without a successful physical-device check.
- Run source analyzer, Flutter/native voice and room regression tests, Vivox packaging and APK signature validation.
- This commit requests a single final Android build for user testing. Do not reset account IDs, rooms, profiles, coins, memberships, gift ownership or transactions.
- If the permanent Android signing identity is unavailable, publish only a clearly labelled ephemeral-key testing APK artifact, not a production-signed release.

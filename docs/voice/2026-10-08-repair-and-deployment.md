# Voice repair and reviewed backend deployment — 8 October 2026

Started from current branch HEAD `5be70e2c7bce9bd5f6685306191675c161242100`. Existing completed work and the `d8468b3` native connector-initialization guard are preserved. No UI redesign or approved/legacy game changes.

## Exact observed live voice blocker

The deployed `voice-token` endpoint responds **HTTP 503** with `{"error":"Vivox voice service is not configured"}`. A read-only diagnostic request reproduced this using the application's public publishable key; no user token, secret, room membership mutation or Vivox credential was manufactured. Supabase function logs independently show repeated `POST | 503` requests on 7–8 October. This function returns that error when one or more required environment values are absent, before attempting user authorization or native SDK initialization/login/join.

Required server configuration: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `VIVOX_SERVER`, `VIVOX_DOMAIN`, `VIVOX_TOKEN_ISSUER`, `VIVOX_TOKEN_KEY`. Configure the genuine matching Vivox environment in Supabase Edge Function secrets; do not put provider signing keys or service-role values in Flutter, Git, release assets or chat. Available tools cannot inspect/set these secrets, and no Vivox credentials are available in this workspace. Consequently the service configuration blocker remains; deploying code or retrying native initialization cannot resolve it. The Edge Function itself was not changed or redeployed.

The user supplied the official public production configuration: server `https://unity.vivox.com/appconfig/18968-nimzo-13904`, domain `mtu1xp.vivox.com`, issuer `18968-nimzo-13904`. A direct HTTPS GET returned HTTP 200 with a `VCConfiguration` XML document whose `DefaultRealm` exactly matches that domain. Preserve the full issuer-specific server URL as supplied; do not replace it with a guessed `/api2/` host or append another endpoint. SDK headers specify the Vivox-provided URL for `acct_mgmt_server`; successful retrieval verifies public configuration reachability/realm, not Android connector or media success. The rotated token key must be configured securely by the user.

A live **authenticated** token issuance test is blocked by the missing service configuration and absence of an authorized test-user access token/current room session in this workspace. No auth token was forged, no account was impersonated and no temporary production account/room was created. Recheck once secrets and a genuine test session are available; validate issuer, account URI, exact room URI, short expiry and listener/seat authorization without printing the returned signed tokens.

## Confirmed code defects repaired

- Flutter started its 25-second media deadline before native login (up to 20s), initial mute (10s) and join acceptance (15s). It now observes native errors immediately but starts the media deadline after the bounded native join response. A slow accepted native join no longer consumes the entire media deadline.
- Pending joins failed only after a timeout when audio disconnected. Disconnect events now fail the pending operation immediately. An audio drop during initial mute cannot result in a successful join.
- Initialization errors arrived before the pending media completer and were lost. Safe status codes are retained. Token HTTP failures and missing configuration now produce actionable diagnostics in the existing room failure text; raw provider payloads/tokens are never displayed or logged.
- Leave/retry previously reused SDK/account/session handles after ignored leave errors/timeouts. The Dart lifecycle now tears down the SDK after leaving and recreates it on rejoin or listener-to-speaker upgrade. Connection and transmit metadata clear after successful teardown. The existing initialization success guard is retained.
- Native response waits artificially added 100ms for every immediately queued message, causing premature timeouts under event traffic. Waits now use a monotonic deadline and bounded remaining-time slices. Native login logout marks audio disconnected, and native logs contain only event names/status codes.

SDK 5.28.0 archive checksum verified: `c30f6caf08184874a7daecc2f9c670df099fa504265dc08b51859e287a38d75f`. Headers and supplied sample confirm authtoken login has no `acct_name` member and channel join supports implicit session-group creation; neither was changed on speculation.

## Authorization and voice validation limits

Live `voice_access` remains service-role-only and checks open room, current membership, active account and no ban; transmission requires an occupied, unlocked, unmuted seat and room permission. Existing ten-seat schema and authorization are preserved. Edge authorization tests cover forbidden members, auth/RPC failures, room-bound signed tokens and listener `join_muted` versus authorized `join`.

Automated tests cover microphone denial, no transmission before audio confirmation, muted initial join, server-denied microphone activation, listener seat upgrade using fresh server credentials, leave/rejoin, cancellation, error/disconnect cleanup and retry. The native host test executes the actual production response-wait function with a queue fixture and verifies both traffic and real timeout behavior. Android/JNI SDK compilation and APK native packaging are checked by the existing GitHub Actions release workflow.

**No device-level voice success is claimed.** No Android SDK/device/`adb` is present locally. Genuine microphone/headset routing, ten-seat moderation on devices, reconnect after real network loss, actual Vivox login/media transport and two-device speaking/listening remain unverified until valid service configuration and devices are available. Provider-enforced moderation/token revocation beyond the existing authorization flow remains outside these repairs.

## Reviewed backend migration: deployed

Applied **only** `supabase/migrations/20261008080810_targeted_backend_contract_repairs.sql` using Supabase migration tooling. Live history records `20261008094444_targeted_backend_contract_repairs`; the management tool assigned its deployment timestamp. Do not create/apply a duplicate migration to reconcile the local filename, or blindly `db push`.

Deployment dependencies/order were checked against a fresh schema-only snapshot. All four original RPC definitions and privileges matched the reviewed baseline. Tables, constraints, policies, indexes, triggers, column grants and other functions were unchanged; the only snapshot variation was equivalent PostgreSQL view deparser parentheses. The repair has no dependency on the undeployed `20261009052036_permanent_room_owner_guard.sql` or `20261007_locked_svip_catalog.sql`; neither was applied. No old room-reset migration was replayed.

Pre-deployment isolated PostgreSQL 17 validation passed. Post-deployment metadata confirms exactly `send_gift`, `send_moment_gift`, `leaderboard` and `vip_status` definitions changed, with signatures/execute grants preserved and all tables, constraints, views and RLS policies unchanged. A fresh post-deployment schema clone passes exact settlement, replay payload rejection, concurrent single settlement, server chat lifecycle, account/settings persistence and active/expired/pre-activation SVIP progress checks. Live read-only checks confirm unsupported daily ranking now fails explicitly and unauthenticated membership status stays empty. Production settlement write paths were not exercised; contract behavior is tested in the isolated clone.

No production profiles, account IDs, rooms, balances, gifts or transaction rows were reset or modified by this deployment. Only four function definitions and migration history changed. Existing security advisor notices were reviewed and remain outside this four-RPC scope; there was no grants/RLS expansion.

## Build and signing

Use `.github/workflows/nimzo-apk-build.yml` on this branch. It installs the verified Vivox SDK, compiles the JNI bridge, runs analyzer, automated Flutter/native/Edge tests, builds `flutter build apk --release`, verifies the APK signature and package/native/OAuth/permission contents, and publishes the APK/checksum/public signer details as a testing prerelease plus an Actions artifact.

The existing generated Flutter Android signing selection is preserved. It currently selects the **development/debug certificate for the release build**; no production keystore/signing properties are provided locally, and GitHub secret listing is unavailable to this integration (HTTP 403). This is a signed testing APK, not an official production-certificate release or a promise of certificate-compatible updating over every previous testing APK. Production signing requires the existing authorized keystore, alias and protected passwords to be supplied through the established secure build environment. No substitute production key is created here.

Reproduce focused validation:

```sh
cd nimzo
flutter analyze
flutter test test/voice test/room_session_test.dart test/backend_targeted_integration_test.dart
cd ..
python3 -m unittest discover -s nimzo/test/voice -p '*_test.py'
node --test supabase/functions/voice-token/tests/authorization.test.mjs
python3 tools/verify_backend_contracts.py --snapshot /tmp/postdeploy-schema.json --concurrent
```

Save the JSON returned by the read-only `tools/backend_contract_snapshot.sql` collector as the snapshot input. It contains schema metadata only. The deployment test runner never connects to Supabase and removes only its own disposable container. Final build outcome, commit SHA and actual download URL are supplied in the task's final report and workflow release assets.

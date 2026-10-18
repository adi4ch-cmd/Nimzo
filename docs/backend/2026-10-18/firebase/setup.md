# Firebase Cloud Messaging setup (Android)

Owner approved FCM only, no Analytics and no APK build. Existing Supabase Auth/database, wallet rules, Games and Vivox remain in place. Firebase Cloud Messaging is free; no Firebase paid product or billing upgrade is required by this integration.

## Owner configuration

1. Sign in at https://console.firebase.google.com/ and create NIMZO on Spark with Google Analytics disabled.
2. Add an Android app with exact package `io.nimzo.app`. Download its **public client** `google-services.json`. This is different from an administrative service-account key.
3. The owner-supplied public client config is stored at `nimzo/config/firebase/google-services.json`; the manual test workflow installs it automatically. GitHub Actions repository secret `NIMZO_FIREBASE_ANDROID_CONFIG` can optionally override it. No APK is automatically triggered; the test workflow remains manual-only.
4. For server sends, create a Firebase service-account credential with the Firebase Cloud Messaging API Admin role. Enable Firebase Cloud Messaging API (HTTP v1). Set the JSON as **Supabase Edge Function secret** `FCM_SERVICE_ACCOUNT_JSON` in the Supabase dashboard. Never commit the key, include it in the app, or paste it into build logs. Store the key directly in the secret manager.
5. Deploy `push-notifications` with JWT verification enabled. The handler accepts only the exact server service-role bearer credential; ordinary authenticated users cannot dispatch push jobs.
6. Schedule the worker only after Firebase secrets and Android configuration exist. Use Supabase Vault for the worker's service credential. Run `activate_scheduler.sql` after creating Vault secret `nimzo_push_worker_service_key` in the dashboard. The credential belongs in neither source nor cron command text. Scheduling is intentionally not activated while configuration is absent.

For a generated local Android host:

```sh
python3 tools/configure_android_firebase.py nimzo/android nimzo/config/firebase/google-services.json
```

The helper creates the standard Firebase resource names from the public client config, declares Android13 notification permission and disables Analytics. This supplies native default-app initialization without requiring the Google Services Gradle plugin. `firebase_core` and `firebase_messaging` are the only Firebase libraries added; the lockfile pins their resolved versions. Runtime requests permission after login; denial leaves in-app notifications usable. Foreground notifications use the existing realtime inbox; background OS notifications carry generic text and IDs only.

## Delivery behavior

- Phone registrations are private and bound to an actual active Supabase session. Rotation replaces the session's previous token; logout removes session tokens before auth is lost. Auth session deletion cascades token deletion. Expired, blocked, inactive, read or disabled-category notifications are filtered from pending sends.
- Only future notification inserts enqueue pushes for currently registered phones. No historical notifications or real-user test events are generated.
- Five jobs are leased for three minutes; sequential5-second FCM and10-second settlement deadlines keep worst-case processing below the lease. Workers cannot concurrently claim the same active lease. Failed sends use bounded retries/backoff; explicit FCM `UNREGISTERED` responses remove invalid tokens.
- An external send and database acknowledgement cannot be atomic. If a process dies after FCM accepts a message, a retry can deliver it again; Android notification tags use the notification ID to replace the same tray item. This is at-least-once delivery, not an exactly-once guarantee.
- Taps accept only matching-recipient notification UUIDs, fetch the actual row through RLS and confirm an owner-only read timestamp before routing. Arbitrary URLs and mismatched-account payloads are ignored.

## Verification and remaining activation

Automated client, Android resource, SQL authorization/session-isolation/queue and HTTP worker tests are provided. They do not prove live FCM delivery. Real delivery still requires the owner's Firebase project configuration, server secret, enabled schedule, and a phone with Google Play services and notification permission. Android force-stop can prevent background delivery until the app is reopened.

No APK is built as part of this setup task. A physical install and foreground/background/terminated-state delivery test remain pending the owner's later APK instruction.

## Deployment evidence —18 October2026

- Migration `20261018084224_firebase_push_delivery` deployed successfully. Sender `push-notifications` deployed version1 with gateway JWT verification enabled. An unauthenticated live HTTP request returned401.
- Public registration/unregistration are security-invoker facades; anonymous calls denied. Claim/settlement RPCs allow service-role execution only. Actual auth.sessions columns were verified before deployment.
- Disposable full-schema SQL tests passed: registration, non-service claim denial, leases, active fifth-attempt protection, five-job batch bound, account-change isolation, expired sessions, logout cleanup and private token access denial. Independent review reported no remaining critical/important issue after fixing batch/lease timing.
- Client5 tests, worker5 tests and tool7 tests passed; worker Deno type check passed. Flutter analysis passed with0 errors/warnings and37 existing infos. Logs are in `firebase/logs/`.
- Existing live data unchanged: profiles3/messages3/notifications86/ledger421; wallet fingerprint `26852a8b5c642128a2e84fb36e2f96f7`. New device and queue counts0. Active push schedule count0. No real-user test notification was inserted.
- Advisors:8 existing no-policy INFO findings,61 authenticated-definer warnings (down from62 because registration now uses an invoker facade) and1 existing password-protection warning. No new finding. See [Supabase definer guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Owner has signed into Firebase console. Firebase project `nimzo-1f296` and matching Android client JSON for `io.nimzo.app` were supplied and connected. The server credential is still absent; automatic delivery and phone testing remain pending.

The GitHub integration cannot write Actions secrets (HTTP403), so the public client JSON is checked in as standard Android app configuration. It contains public Firebase identifiers/API configuration, not a service-account private key. Server credentials remain excluded from source. No permission change is required for this fallback.

Final full Flutter run:377 passed, with the same3 owner-deferred golden suites failing (`master_visual_preview_test`, `reference_preview_test`, `remaining_visual_qa_test`). No new failure. Screenshots were neither blessed nor tests disabled. Public Android configuration was verified through the real resource helper; no APK was built.

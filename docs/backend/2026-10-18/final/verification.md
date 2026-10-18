# Final backend and Android verification — 18 October 2026

## Scope and baseline

Continued from ef43c06 on feature/tingle-ui-rebuild-20261017, including merged PR21. Preserved app design and existing Supabase/Firebase/Vivox integrations. No production release, user deletion, balance reset or game odds change. Metadata inspection covered 59 public and 10 private tables, functions, policies, triggers and storage policies before changes.

## Firebase verification

| Requested existing state | Result |
|---|---|
| Android registration/config | nimzo-1f296, io.nimzo.app, existing non-secret client JSON retained |
| Flutter SDK and gateway | Existing firebase_core/firebase_messaging and lifecycle verified |
| PR21 host and Actions config | Present at baseline; preserved |
| Vault Admin credential | nimzo_fcm_service_account exists; value never retrieved into local logs/code |
| Reader | anon/authenticated execute=false; service_role=true, invoker public facade/private guarded reader |
| Worker | Baseline v2 active; reviewed source deployed as v3, verify_jwt=true |
| Device/queue RPCs and tables | Existing register/unregister/claim/finish and private queue/device tables verified |
| Devices/jobs | 0 registered devices, 0 jobs at inspection |
| Scheduling | Previously absent; scoped HMAC/nonce dispatcher now scheduled every minute, first cron execution succeeded |

Forced signed request returned HTTP200, processed0/sent0, oauth=ok and validation=INVALID_ARGUMENT for an intentionally invalid synthetic token in FCM validate-only mode. This confirms Admin OAuth generation and FCM HTTP v1 reachability/validation response. **It does not confirm delivery to a phone.** No real device was available or registered.

The scheduler retains gateway JWT verification and never exports a service-role key. One-time HMAC nonces and 90-second signature lifetime prevent replay. Admin key stays in the existing Vault secret. Idle ticks avoid network requests. Existing queue leases, retries, invalid-token cleanup, session/preference/status/block filtering remain covered by disposable database and worker fixtures.

Android foreground display now uses a local notification channel with sound/vibration and generic text. Background/terminated delivery uses FCM notification payloads; tap handling fetches authorized server-side notification identity before routing. Personal messages, gifts, followed-room activity, follow events, admin announcements and account status map to authenticated destinations. Legacy follow/membership events remain. No private message body is exposed in notification payloads. An already accepted OS notification can appear after account switching, but contains generic text; wrong-recipient taps/foreground display are rejected.

## Database and client changes

Applied migrations:

- 20261018142449_secure_push_dispatch
- 20261018142454_notification_events_and_account_guards
- 20261018142455_game_retry_payload_guard

Changes add notification event identities/deduplication and followed-room activity; enforce active sender/recipient accounts; serialize reseller retries across recipient changes; require unchanged game retry payload; guard diamond exchange for inactive accounts. Existing RNG, payouts, gift settlement percentages and wallet balances remain untouched. Public privileged entrypoints keep server-side checks; Vault/dispatcher internals are inaccessible to mobile roles.

Existing policies and tests cover profile/avatar/country ownership, persistent owned room IDs and 10 seats, moderation permissions, Moments/media ownership, messages, support/settings and Family create1M/joinfree. Rewards stay disabled; VIP/SVIP/Store remain Coming Soon. Email/Google/Facebook login paths remain; no phone login added. Existing account deletion API records a request rather than deleting records automatically.

Approved existing economy checked: 1USD=500000coins; eligible gift recipient45%diamonds; diamond-to-coin1:1. Existing room-owner bonus unchanged. Concurrent gift/room/Moment sends, diamond exchange, game retry and reseller payload changes tested on synthetic local fixtures, never real production users.

**Unresolved historical ledger discrepancy:** one production wallet has49,906,000 more coins than recorded ledger totals. No supporting purchase/credit record establishes an authorized correction. No balance or guessed adjustment was written. Requires owner/source-record review. Baseline/post-deploy profile/message/Moment/ledger counts remain3/3/3/421.

## Tests and limits

| Check | Result |
|---|---|
| Flutter dependency resolution | Passed locally; CI repeats |
| Flutter analysis | 0 errors,0 warnings;37 existing informational findings |
| Full Flutter suite | 380 passed,3 pre-existing deferred screenshot failures |
| Deferred screenshots | master_visual_preview_test, reference_preview_test, remaining_visual_qa_test; not regenerated or hidden |
| Node worker/voice/purchase tests | 24 passed |
| Python Android/workflow verification | 12 passed, including startup/dependency guards |
| Full cloned Postgres migration/RLS suite | Passed, including actual storage policies and concurrent economic operations |
| Social/session/Family/media/push suite | Passed |
| Independent final security review | No critical defect; important release-smoke gating finding fixed |
| Production Vault grants/scheduler | Verified restrictive grants and successful cron run |

Database tests use a disposable metadata clone and synthetic fixtures. Their local Vault/net shims do not represent provider delivery. Schema constraints and real storage policy expressions were replayed. Existing Supabase advisory findings remain, including password-protection setting and authenticated definer exposure requiring routine review; a passing fixture suite is not a claim that all production systems are ready.

## Pending external validation

- Real Android FCM token/foreground/background/terminated delivery and tap test; no physical device access.
- Real Google/Facebook provider login and authenticated Vivox network reconnect/microphone behavior require device/provider sessions. Local session, logout, permission and voice lifecycle tests pass.
- iOS Firebase plist/APNs credentials and native Vivox iOS SDK were not supplied; no complete iOS delivery/build claim.
- Romantic Blossom, Ice Queen Magic and Tiger Warrior remain inactive at500000coins in the staged manifest. Original demo files are absent from this checkout; no MP4 was mislabeled as transparent VAP. Full-collection activation remains deferred as requested.
- Historical49,906,000coin reconciliation above remains open.

## APK evidence

The branch-only Actions workflow compiles release mode using a development signing certificate, verifies io.nimzo.app/version/Firebase resources/native libraries/no detected privileged client credential, then requires emulator installation and startup before uploading the verified artifact. It does not publish a production release or replace the permanent updater certificate. Final run/artifact evidence is recorded after completion.

Supabase advisory references (existing categories): [RLS without a policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [authenticated SECURITY DEFINER entrypoints](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Deny-by-default tables and guarded RPCs need context; the categories alone are not proof of exploitable access.

Post-deployment negative auth checks: requests without Authorization and with the public anon JWT but no scoped signature both returned HTTP401. The cron signed request returned200. Existing game catalog has two enabled legacy RPC-backed games; the additional approved UI boards remain previews rather than invented payable engines. Real-money purchase-provider settlement and real network game play are not claimed from synthetic transaction tests.

Live Auth settings returned200: **email, google and facebook enabled; phone and all other providers disabled**. This verifies provider configuration, not a completed interactive provider login on a physical device.

CI source QA [39135966001](https://github.com/adi4ch-cmd/Nimzo/actions/runs/39135966001) reproduced exactly380 passing tests and the same3 deferred screenshot failures. Initial release run [39135986690](https://github.com/adi4ch-cmd/Nimzo/actions/runs/39135986690) passed static package/native checks but was rejected after manual launch-log/screenshot review: the process survived while a SharedPreferences NoSuchMethodError stranded startup. Its APK is not approved for delivery. Root cause: Flutter create unconditionally rewrites pubspec.lock, silently resolving an unreviewed newer Android plugin graph. The workflow now generates without pub resolution, restores the committed lockfile and uses pub get --enforce-lockfile. Launch verification now rejects unhandled Dart startup exceptions even when the process remains alive. A corrected APK is being rebuilt.

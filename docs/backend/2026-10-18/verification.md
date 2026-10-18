# Backend continuation — 18 October 2026

Continued from 508c9c1 on feature/tingle-ui-rebuild-20261017. Owner approved Purple Gold microphone/N logo, backend development, free Family join and exactly 1,000,000 coins for Family creation.

Implemented:
- Approved logo in login/register and persistent Android launcher inputs. Test workflow includes unchanged native Vivox integration, OAuth callback and permissions; APK verifier checks package, signature, native libraries and bundled logo.
- Authenticated Family directory, creation confirmation with explicit cost, free join/leave and own/joined families pinned independently of newest 100 public entries. One owned Family per account.
- Atomic server creation: active account, locked wallet, exact 1M debit, matching ledger record, request-key replay/payload verification; authenticated direct inserts denied. Failed creation rolls back; retries and concurrent same-key calls debit once.
- Up to nine Moment photos, add/remove previews and horizontal feed gallery. Author-only writes, path ownership and media count validation. Existing single-photo rows and legacy feed retained.

Migration deployed successfully: `20261018035405_family_and_moment_media`. Public feed is security invoker; privileged financial implementation is private with auth checks. No game rules, global wallet rules, voice implementation, accounts or balances were reset. Creation charges occur only when a user submits the explicit paid action.

Validation:
- Full live **schema-only** metadata cloned into disposable PostgreSQL 17; no real users copied. Migration, RLS, media ownership, insufficient balance, direct-insert bypass denial, exact debit, replay conflicts and two-session concurrent debit pass. Reproduce using `python3 tools/verify_social_backend.py --snapshot <schema_snapshot.json>`; snapshot query is tools/backend_contract_snapshot.sql. Fixed snapshot replay support for generated columns and table-level grants.
- Before/after live checks: wallet fingerprint unchanged; ledger421, profiles3, Moments3; two existing media posts backfilled. New Family count0. No live user charged for tests. New feed readable; unauthenticated creation denied.
- Final live contract check:54 statically referenced Flutter RPC calls matched deployed function names and required/optional parameter names;0 mismatches. Public Auth settings confirmed Email/Facebook/Google enabled, signup allowed, and app targets the Nimzo project. This is configuration/contract evidence, not a claim that every provider/device flow is exercised.
- Flutter analyze --no-fatal-infos: exit0, 0 errors/warnings, 37 existing infos.
- Final full Flutter suite: 357 pass / 3 existing golden failures: master_visual_preview_test room overlay; reference_preview_test approved boards/empty home; remaining_visual_qa_test remaining reference screenshots. Baselines not rewritten or disabled.
- Subsequent focused Family repository tests:3 pass; Moments/editor/Family tests:7 pass. Screenshot capture login/Family/composer:3 tests pass at320/360/390. Screenshot fixture precaches the actual approved logo before capturing; image decoding is asserted.
- Tool workflow contracts:5 pass. Disposable schema behavior and concurrent transactions pass. Independent review found the old-family accessibility issue, which was fixed and regression tested; final security review found no remaining critical/important issue.
- Supabase security advisors unchanged:8 no-policy INFO notices,62 existing authenticated SECURITY DEFINER warnings and existing leaked-password-protection warning. New features introduced no new advisor notices. See [advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Remaining product/provider decisions:
- Owner confirmed VIP, SVIP and Store must stay paused. All taps (including Backpack, task and Honor Wall Store links) show Coming soon without navigation. Direct links, query variants and trailing slash URLs redirect to Profile; paused screens have no router builders. Membership backend remains retired.
- Owner confirmed daily/task, CP and referral rewards must remain disabled. Store UI is paused; existing server catalog/ownership records remain intact. No prices or rewards invented.
- Physical microphone/OAuth/purchases/push delivery require provider accounts and device validation. No physical device available in this workspace. Existing device-token registration alone is not evidence of end-to-end push delivery.

No merge, production APK release or updater publication. The owner subsequently deferred further APK work until backend completion.

Follow-up paused-feature tests:20 pass, including real Profile taps, authentication precedence and actual router deep-link rejection. Final full suite357 pass/3 existing golden failures. Further APK work is deferred by the owner.

## Backend continuation after owner deferred APK

Owner confirmed all daily/task, CP and referral rewards stay disabled. Owner has no Firebase project. VIP/SVIP/Store/Backpack remain Coming soon. APK workflow is now manual-only; no new build or production release was requested or dispatched during this continuation.

Additional implementation:
- Pair-scoped message history: stable timestamp/ID pagination, load earlier messages, realtime refresh, overlap deduplication and reconnect-gap recovery. A stored canonical conversation key and index bound queries to one participant pair; existing message RLS remains authoritative.
- Social notifications for new follows, friend requests/acceptance and CP requests/acceptance. Blocked and self events are suppressed. Opening a notification confirms an owner-only server read timestamp before navigating to its actor or CP page. Historical activities were not backfilled.
- Session-based online presence: server timestamps, 90-second expiry, 30-second foreground heartbeat, multi-device aggregation and mutual-block privacy. Unknown presence stays unknown. Requests are deduplicated and split into batches of at most100 peers; one offline device cannot erase another active device.
- CP duration now uses persisted relationship creation time and a disposable one-second clock. No CP points or rewards invented.

Deployed migrations: `20261018082326_conversation_history`, `20261018082329_social_notifications`, `20261018082335_account_presence`. Public RPC facades are security invoker; private implementations authenticate and anonymous execution is denied. Presence session identifiers are never exposed to clients.

Validation of this continuation:
- Disposable PostgreSQL17 schema clone passes Family/media, exact/concurrent1M debit, free join, message-pair isolation, social-event delivery/block filtering, owner-only notification reads, session privacy/multi-device expiry and disabled reward bypass tests. The disabled daily reward test verifies both wallet and ledger remain unchanged; direct check-in inserts are denied.
- Live before/after: profiles3, messages3, notifications86, ledger421, Moments3, Families0, presence sessions0. Wallet fingerprint unchanged (`26852a8b5c642128a2e84fb36e2f96f7`). No real messages, notifications, Family charges or presence sessions were generated for testing.
- Live Flutter RPC contract check:57 calls,0 mismatches. New columns/indexes installed, authenticated RPC permission granted and anonymous permission denied.
- Security advisors unchanged:8 existing no-policy INFO findings,62 existing authenticated-definer warnings and1 existing password-protection warning; no additional finding from these migrations.
- Voice-token and purchase-verification handler tests:18 pass. Tool/workflow tests:5 pass. These are automated checks, not real provider transactions.
- Independent read-only review found and verified fixes for reconnect history gaps and more-than100-peer presence; final review reported no remaining critical/important issue.

Provider/device limits remain explicit: phone background push cannot be completed without Firebase project/configuration; in-app notifications are implemented. Physical OAuth, microphone and purchase delivery still require device/provider validation. No claim of end-to-end phone delivery or completely verified production backend is made.

Final continuation analyzer: `flutter analyze --no-fatal-infos` passed with0 errors,0 warnings and37 existing infos.

Final continuation full Flutter suite: **372 passed /3 existing golden failures** in the same three named suites above. No new failing test; baselines were not regenerated and tests were not disabled. Logs are retained alongside this report.

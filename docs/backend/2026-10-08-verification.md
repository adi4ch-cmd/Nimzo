# Targeted backend verification — 8 October 2026

Baseline: `8ee45c19655f71d3ce6c2bd3a3da60786373db92`, branch `feature/profile-reference-redesign`.

Deployment update: the reviewed four-function repair was subsequently deployed as live migration `20261008094444` under the user-authorized voice/deployment task. See [deployment evidence](../voice/2026-10-08-repair-and-deployment.md). Statements below describe the earlier read-only verification checkpoint.
UI development is finished. This pass changes data bindings and confirmed backend defects only; no game engine, payment simulation, catalog redesign or existing visual tests.

## What was actually checked

Read-only Supabase access was available for project `kvqvlpozqokwarovwmwv` (Nimzo, ACTIVE_HEALTHY, PostgreSQL 17.6). Checked deployed migration history, function definitions and grants, columns, constraints, RLS policies, realtime publication, Edge Function source and aggregate invariants. No production inserts, updates, deletes, migrations, purchases or gifts were executed. An authenticated-role visibility probe used a nil user UUID inside a READ ONLY transaction and rolled back.

| Evidence | Live result |
| --- | --- |
| Migration history | 34 deployed migrations, including premium security, opening ledger entry and profile collections/CP requests |
| Public/private RPC definitions | 55 public + 6 private functions inspected; all 35 literal Flutter RPC names exist live |
| Edge Functions | `voice-token` v4 and `verify-purchase` v4 ACTIVE; source matches root repository source after trimming outer whitespace; JWT verification enabled |
| Public-table RLS | All 45 public tables enabled; protected profile counters and wallet balances not client-updatable |
| Wallet/ledger/purchase/chat read probe | Zero visible rows for the unaffiliated test identity |
| Aggregate invariants | Zero duplicate owner rooms or current memberships; zero room-number/owner-ID mismatches, invalid seats, rooms missing ten seats, missing profile wallets or orphan auth profiles |
| Room view | `rooms_ranked` uses `security_invoker=true`; safe projection excludes password hash |
| Realtime | Room/message/member/seat/gift/notification/wallet publication entries verified |

RPC write behavior was verified separately against a **schema-only disposable PostgreSQL 17 clone**, using the deployed function definitions, policies, constraints, column grants and execute privileges. The clone contains only isolated synthetic contract fixtures. This verifies database contracts, not production write paths, GoTrue session issuance, provider credentials, realtime delivery or real purchase/voice behavior.

## Implemented contracts versus remaining work

| Area | Implemented/deployed | Missing or unverified |
| --- | --- | --- |
| Accounts/settings | Auth profile/wallet initialization, protected profile counters, own-row profile updates; language/country persistence verified in clone | Real OAuth/device sign-in and account lifecycle not exercised. No authoritative privacy/notification preference table or RPC; those settings require a scoped contract before implementation |
| Rooms | `create_room`, `join_room`, `leave_room`; permanent room number equals owner Nimzo ID; ten seats; RPC/profile locking and one-current-membership index | Local `20261009052036_permanent_room_owner_guard.sql` is absent from live history. Live owner uniqueness covers open rooms; additional all-status owner/schema guard is not deployed. Supported RPC and existing room-number uniqueness prevent a second room; arbitrary direct-write/admin paths were not exercised |
| Chat | Membership/join-time RLS, database-clock timestamps; own-message cleanup and re-entry isolation verified | Realtime/device transport not end-to-end tested. Client timestamp filtering was removed to avoid hiding server-authorized chat under phone clock skew |
| Gifts/wallet | Room 45% recipient/5% owner settlement with self-credit exclusions; Moment/profile gifting; ledger, reconciliation and column/RLS guards | Live room/Moment replay bugs remain until the staged repair is deployed; no live settlement was performed |
| Ranking | Existing `leaderboard` supports Wealth/Charm/Room, weekly rolling 7 days and monthly rolling 30 days; all six client combinations tested | Daily/Gift/Active do not have distinct authoritative contracts. Live daily requests silently fall through to weekly; staged patch rejects them. Charm self-gift overcount repaired in staged SQL |
| Levels/progress | `wealth_coins`, `charm_diamonds`, `active_points` stored totals now exposed; unsupported levels/thresholds are not invented | No authoritative level thresholds or activity accumulation policy. Stored zero activity is not evidence of a completed activity/reward engine |
| VIP/SVIP | Effective `vip_status`, daily VIP claims, Friday SVIP claims, recharge-maintained counters and catalogs exist | Live SVIP catalog has **8 legacy tiers**, not locked 10; `20261007_locked_svip_catalog.sql` is not deployed. Sunday 21:00 Asia/Riyadh reward scheduler/contract missing. New server cycle-progress fields are staged, so progress intentionally stays unavailable on the old RPC rather than showing expired totals. VIP native purchase/product activation flow not verified |
| Payments | ACTIVE `verify-purchase` and service-role-only `apply_recharge`; provider receipt verification, product matching and receipt/owner replay guard exist | Native store purchase integration, credentials, store products, webhook/lifecycle handling and real receipts not verified; no fabricated recharge or payment was introduced |
| Voice | ACTIVE server token endpoint plus service-role voice access check | Vivox credentials/provider sessions not verified. Forced mute/kick token revocation/admin moderation requires provider-side integration; local UI state alone is insufficient |
| Approved seven games | Client keeps approved catalog unavailable without matching contracts | No matching authoritative contracts for the seven approved games. Live `fruit_wheel`/`fruit_party` are unrelated legacy engines and remain untouched/unmapped |
| CP/profile collections | Profile gifts, tags/photos, visit statistics, couple requests and security wrappers deployed | Physical-device/production request workflows not exercised |
| Tasks/store/PK/treasure/push | Existing UI availability guards preserved; device-token registration contract exists | Authoritative eligibility, product ownership/inventory, claim schedules, settlement and delivery contracts needed for unsupported actions; FCM delivery/provider credentials unverified |

## Confirmed repairs

Staged migration `20261008080810_targeted_backend_contract_repairs.sql` replaces four existing functions while preserving signatures and privileges:

1. Room and Moment gift idempotency: transaction advisory locks serialize identical sender/key requests; committed replay must match the original target/recipient/gift/quantity. Changed payloads fail without another debit. Existing settlement math and permissions are unchanged.
2. Charm leaderboard excludes self-gifts, matching actual settled recipient diamonds. Unsupported periods fail explicitly instead of returning a different period.
3. `vip_status` adds current-cycle cents and active-cycle status using the existing server 90-day expiry rule. Historical profile counters remain untouched; expired cycles report zero current progress, while below-threshold pre-activation recharge is retained.

Flutter changes validate supported ranking combinations, expose real counters, use deployed SVIP thresholds and server cycle status, and rely on server chat visibility. Existing language/settings persistence is retained and tested; no speculative preferences migration was added.

**The migration has not been applied to production.** These RPC fixes and new current-cycle fields are locally verified, not live deployed. Deployment must reconcile the repository's two undeployed 20261007 migrations and their catalog/ownership implications; do not blindly `db push` or replay historical room-reset migrations. Only the targeted replacements belong to this repair.

## Reproduction and results

- Read-only collector: `tools/backend_contract_snapshot.sql`. Save its `schema_snapshot` JSON value as a local file; it contains schema/code/grants, not production rows or credentials.
- Disposable validation: `python3 tools/verify_backend_contracts.py --snapshot /tmp/schema.json --migration supabase/migrations/20261008080810_targeted_backend_contract_repairs.sql`.
- Focused Flutter suite: `cd nimzo && flutter test test/backend_targeted_integration_test.dart`.
- Analyzer: `cd nimzo && flutter analyze`.

The unchanged live snapshot reproduced the changed-recipient gift replay failure before repair. Patched SQL passes room IDs/ten seats/one membership, wallet RLS, protected counters, language persistence, exact settlement splits, replay payload binding, self-gift exclusion, unsupported periods, server chat cleanup/re-entry, real counters and active/expired/pre-activation SVIP cycle progress. Separate two-session tests exercise identical and changed-payload room/Moment retries and verify a single ledger settlement/debit. All 17 focused Flutter tests pass; analyzer reports no issues. Focused Flutter tests cover supported/unsupported ranking requests, counter precision and absent fields, catalog sourcing, failed status, asynchronous failure handling and chat under phone clock skew. Existing UI/golden/game test suites are not rerun manually in this backend pass.

## External contracts and credentials still required

No credential values were read or printed.

- **Vivox:** `VIVOX_SERVER`, `VIVOX_DOMAIN`, `VIVOX_TOKEN_ISSUER`, `VIVOX_TOKEN_KEY`; server-only Supabase URL/service-role secret for token authorization. Need provider admin/moderation authentication, revoke/kick/mute semantics and verified channel/session lifecycle.
- **Google Play:** `GOOGLE_PLAY_SERVICE_ACCOUNT`, `GOOGLE_PLAY_PACKAGE_NAME`, Play Developer API permission and real configured products/package/signature; native purchase token delivery and replay-safe verified settlement. Do not infer credential readiness from ACTIVE deployment.
- **Apple:** `APP_STORE_SHARED_SECRET`, `APP_STORE_BUNDLE_ID` for the existing verification path; real configured products/receipts. Modern App Store Server API/notification lifecycle needs an explicit separately reviewed provider contract.
- **OAuth/push:** provider client configuration, Android signing fingerprints/redirects and verified device flows; FCM delivery service identity and invalid-token handling. Registration does not establish notification delivery.
- **Seven approved games:** exact catalog IDs, rounds/configuration, entry/eligibility, wager/play RPC, server-generated outcome, settlement, history and idempotency contracts for each approved game. Legacy fruit contracts are not substitutes.
- **Unsupported settings/tasks/store/rewards/PK/treasure:** owner-scoped preferences; authoritative catalog/inventory and ownership; eligibility/cooldown/schedule rules; server atomic debit/credit or award with idempotency and RLS. Implement only once these contracts exist and match approved product rules.

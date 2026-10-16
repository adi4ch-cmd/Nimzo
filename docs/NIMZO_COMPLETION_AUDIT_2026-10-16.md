# Nimzo existing-feature audit, 2026-10-16

Baseline: `fix/remove-vip-svip-all-20261016`, commit `7650237`. This includes the
level repair and complete membership retirement. `main` is an older scaffold.
Scope: repair existing features and deliver an APK; new games and Task reward
rules are deferred by the user.

## Confirmed repairs

- Current Flutter templates omit the applied Kotlin plugin when using built-in
  Kotlin. Nimzo pins AGP 8, so the Android configuration now explicitly applies
  external Kotlin before Flutter. The regression failed before the fix and
  passes afterwards, including repeat configuration.
- Live private-schema lockdown broke four public profile RPCs: gifts, visitor
  recording, profile statistics and couple-request responses. The migration
  `20261016092154_repair_private_profile_rpc_facades.sql` restores their explicit
  authenticated API boundary, pins the empty search path, checks `auth.uid()`,
  preserves private ownership/consent/block/wallet/idempotency rules, and revokes
  direct client execution of the private implementations. Private schema access
  and backup-table access remain denied. Rehearsed in rollback transactions,
  then deployed to project `kvqvlpozqokwarovwmwv`.
- Settings/support test assertions now scope privileged fixture checks to fixture
  users, rather than counting unrelated live notifications or selecting existing
  users' support tickets.
- Updated stale scaffold documentation and release version to 1.0.28+128. The
  dependency lockfile is preserved.
- Repaired the concurrently enabled profile self-gift's distinct-wallet count.
  Self gifts lock one wallet; gifts to another user still require two. Live
  rollback tests confirm a 1000-coin self gift credits 450 diamonds, identical
  retries settle once, changed retry payloads fail, and ordinary gifting works.
  Migration `20261016092553_repair_self_profile_gift_wallet_lock.sql` was rehearsed
  and deployed. The prerequisite is archived under `docs/backend` with provenance
  commit `f4fd351`; it is documentation, not a migration to run again.

## Verification

- Flutter analyzer: no issues. Both complete Flutter runs: 298 passed each.
- Python release/build checks: 10 passed; native voice: 7 passed; native updater:
  1 passed with Java 17; reference asset integrity: 1 passed.
- Edge Function voice-token and purchase authorization: 18 passed.
- All 12 original room Rocket clips verified by SHA-256. Vivox SDK archive
  verified against `c30f6caf08184874a7daecc2f9c670df099fa504265dc08b51859e287a38d75f`.
- Live read-only checks passed for VIP/SVIP removal, gift broadcasts, gift
  Realtime privileges, RLS on all public tables and security-invoker ranking view.
- Live rollback suites passed for profiles, self-profile gifts, room moderation and settings/support, including
  consent/authorization and notification preferences. Public RPC login/private
  access checks passed. No fixture Auth users remained afterwards.

## Limits and current observations

The database changed concurrently during this audit: migrations
`allow_self_profile_gifts_45percent` and
`backfill_verified_unpaid_self_gift_diamonds` appeared from another work stream.
The newly enabled profile self-gift checked for two distinct wallets and failed
with `wallet unavailable`. The narrow repair follows that explicitly deployed
allow-self rule, without changing the 45% settlement policy. Profile behavior
tests now reflect that rule rather than the obsolete self-gift-denial assertion.
Room/Moment self-gifts are separate existing features.

Supabase advisors still report intentionally locked private tables without client
policies, authenticated SECURITY DEFINER API entry points, and disabled leaked
password protection. The facade entry points intentionally add four guarded API
warnings. These are not a claim of a full penetration test. Guidance:
https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
and https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Performance advisors also report five unindexed foreign keys, 28 RLS initplan
warnings, seven overlapping-policy warnings and ten unused-index notices. These
are recorded rather than changing unrelated access policies or deleting indexes
without workload evidence.

The permanent signing key is not available in this environment. Any APK delivered
from this run uses test signing and must stay outside the permanent automatic
update channel. Different existing signing certificates prevent in-place updates.
Physical-device installation, two-device voice, OAuth browser return and real
store payments are not verified here. Additional games/reward economics and legal
document approval remain product/provider inputs, outside the confirmed fixes.

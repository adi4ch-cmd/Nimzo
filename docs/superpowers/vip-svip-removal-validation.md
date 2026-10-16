# VIP/SVIP retirement validation

## Scope and baseline

The user replaced the free VIP rebuild with complete removal, including existing users. Work starts from feature/profile-reference-redesign at 28de8d05b90f637ac4d88a4fc260aa5cc4cf433c. Main is older and does not contain that branch.

## Live database

Project: NIMZO (`kvqvlpozqokwarovwmwv`). Applied migration: `20261016040304_retire_all_vip_svip.sql`.

The initial assertion failed because one profile retained legacy membership fields. Before resetting, the transaction saved public table rows, public/private function definitions and permissions, trigger definitions and cron configuration in `nimzo_private.membership_retirement_backup`, keyed by `retire-vip-svip-v1`. There are 146 snapshot objects, including the original assignment. The archive denies anon/authenticated schema access and has RLS with no client policies. Reapplication uses ON CONFLICT DO NOTHING, preserving originals.

This is an access-restricted logical data/affected-definition backup, not a full pg_dump, Auth/Storage backup or independently tested PITR image. It does not include storage object bytes. Historical entitlement fields, purchase/ledger rows and payout-run records remain for audit. Do not restore wallet snapshots over subsequent legitimate financial activity. Recovery of legacy membership would require an explicit maintenance operation to remove the retirement invariant and restore the selected archived definitions/assignment fields; no automatic rollback runs in the app.

The migration compares every public table before/after while holding deterministic table locks. Only the five active membership fields on profiles and two gift membership gates may change. Any other changed row aborts the entire transaction. Accounts, profile details, IDs, wallet balances, levels, gifts/prices, transactions, admins, resellers and unrelated collectibles were preserved by this assertion.

Post-deployment verification found 3 profiles, zero old assignments, zero membership-related profile tags/collectibles/store items, and the Sunday SVIP job inactive. Purchase, activation and claim RPCs reject without writes, stale membership reads return zero, room entry trigger is removed, moderation no longer has an SVIP exception, and a trigger rejects new membership assignments. Recharge retains its receipt validation, serialization, exact replay handling and coin credit, with automatic SVIP removed.

## Database behavior checks

`supabase/tests/vip_svip_retirement.sql` verifies zero assignments and gift gates, disabled scheduler/entry trigger, private archive access, rejected purchases/activation/rewards/regrant, neutral status, and unchanged wallets/ledger/purchase counts. Generated transaction-only Auth fixtures verify recharge credits once, replay does not duplicate credit, diamonds do not change, cross-account receipt replay fails, and recharge never grants VIP/SVIP. Fixture subtransactions roll back their rows and credits; normal database sequences may advance without renumbering existing IDs.

Before deployment, ran migration + tests twice in one rollback transaction. Verified the live original assignment still existed after rollback. After authorized deployment, ran the behavior suite again inside BEGIN/ROLLBACK. No Supabase staging branch existed; these are rollback rehearsals and production postchecks, not a staging deployment claim.

Security advisor: new backup-table “RLS enabled, no policy” info is deliberate deny-all client access. Existing project warnings remain for signed-in SECURITY DEFINER RPCs and disabled leaked-password protection; this change does not claim a full application security audit. Guidance: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy and https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .

## Flutter and Android

Removed membership implementation modules, licensed membership-only assets, profile badges/cards, tier selectors, purchase/reward actions, identity effects, room entry listeners/animations and obsolete asset-install/golden workflows. Normal profile names/avatars, gifts, store collectibles and voice behavior remain. Both historical membership URLs open a truly empty Scaffold. Me no longer advertises memberships. No replacement activation is offered.

FilePicker v11 had a pre-existing build failure (`FilePicker.platform` removed); changed to its supported static `FilePicker.pickFiles` API. Lockfile now records the dependencies already declared by the branch. App version is 1.0.24+124.

Local verification on Flutter 3.47.6 / Dart 3.13.5: flutter analyze reported no issues; all 296 Flutter tests passed, including actual production-router /vip and /svip blank-page checks, profile/room no-membership assertions, seat/mini-profile behavior and Vivox state/reconnect tests. Node voice-token/purchase authorization suites passed 18 tests; native voice checks passed 7; native update downloader checks passed 1 after installing Java 17; release workflow tests passed 4; reference-asset integrity passed 1. All 12 original room Rocket VAP files passed SHA-256 verification. No native Vivox source was changed.

Independent whole-change review found no Critical/Important issues. Both minor observations were addressed: use production router wiring in blank-page tests and remove unused VIP/SVIP emblem assets. Router auth subscription now uses the existing injectable Supabase provider, preserving the production client while allowing actual router verification. Obsolete membership-only backend suites were retired; unrelated moderation tests now verify absence of immunity and passed in a rollback transaction with owner/mod/admin boundaries intact.

The release workflow builds the native Vivox APK and now performs Android emulator installation and a 20-second process/crash smoke check with logcat and screenshot artifacts. The completed workflow run and actual APK download URL are supplied in the final delivery message, rather than predicting an unbuilt URL here. Physical Android installation, two-device audio/OAuth/store purchases and a separate staging deployment cannot be claimed without those environments.

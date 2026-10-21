# NIMZO legacy VIP/SVIP cleanup — 2026-10-21

**Branch:** `feature/membership-reset-20261021`. Base: `fix/premium-store-integration`, to avoid overwriting newer Store and Vivox work.

## GitHub
- Removed VIP/SVIP UI routes, profile/Me badges, membership shortcuts, SVIP room entry effect, dedicated membership UI Dart files and membership-only test modules.
- Removed 180 bundled `assets/willchill_premium/vip/` and `/svip/` files; manifest now contains 261 remaining independent Store/gift/game/media items. Do not import the original 441-file package unfiltered.
- Removed VIP/SVIP fields from Flutter Profile model. The room gift, Rocket, Store, Backpack and audio paths remain unchanged.
- No production APK or device test completed. Previous full suite had known failures. Validate Flutter analyzer, unit/widget tests, Android startup and gift playback before release.

## Live Supabase — Nimzo (existing project)
Applied and verified:
1. The 4 retired VIP/SVIP public catalog/reward tables moved to access-restricted `nimzo_private` schema.
2. The 6 retired public VIP/SVIP RPC endpoints dropped.
3. Legacy SVIP Sunday scheduled job unscheduled and private worker functions removed.
4. Existing profile VIP/SVIP levels, expiry, cycle and reward-claim data neutralized.
5. Gift `min_vip`/`min_svip` gate values neutralized.
6. Private snapshot `nimzo_private.membership_cleanup_snapshot_20261021` preserves previous profile membership fields; existing `nimzo_private.membership_retirement_backup` retains historical rollback definitions and tables.

Verification after migration: zero public legacy membership tables; zero retired public membership RPCs; zero active assignments; zero gift VIP/SVIP gates; no old SVIP scheduled job; private profile backup has 3 rows.

## Completed follow-up: legacy fields physically removed
- Snapshot of all 3 profile rows retained privately before dropping legacy fields.
- The 5 live gift/moment/profile-gift and moderation functions were backed up, then updated to remove only legacy tier checks while preserving authentication, anti-replay, wallet debits, receiver credits, moderation authorization and row locking.
- 7 historical VIP/SVIP columns were dropped from `public.profiles`; 2 membership requirement columns were dropped from `public.gifts`.
- `reject_retired_membership` trigger and function were removed after the columns were dropped.
- Verification: zero VIP/SVIP columns in the public profile and gift tables, zero public legacy VIP/SVIP RPCs, zero remaining live SQL functions containing VIP/SVIP references, 3 profiles preserved and 29 gift catalog rows preserved.
- Applied Supabase migration: `20261021010526_remove_vip_svip_fields_and_gates_20261021`. GitHub source migration now records the resulting function definitions.
- Static review checked all 158 current app Dart files and 126 Flutter test Dart files for deleted membership classes/routes. Repaired obsolete profile/navigation/walkthrough/backend test assumptions.
- **No Flutter build, complete test suite, or real device APK smoke test has run on this branch.** GitHub Actions currently shows no workflow runs for it; this is not a verified APK release.

User accounts, balances, ledger, gifts, rooms and purchases were not erased. Old branches and Git history still retain previous content for rollback.

## New Codex task
Use `feature/membership-reset-20261021` as source baseline. Build fresh VIP/SVIP semantics, user interface, assets and backend independently after auditing existing dependencies; do not copy the retired purchase/entitlement code. Keep Store equipment, gifts and room voice intact. Validate every new function with secure RLS, transactional privileges, and tests.

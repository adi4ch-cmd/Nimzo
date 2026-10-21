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

## Important compatibility boundary
The **seven legacy membership columns in public.profiles** and two gift-level columns are intentionally kept at neutral values until the active SQL functions `public.send_gift`, `public.send_moment_gift`, `nimzo_private.send_profile_gift`, `public.kick_member`, and `public.moderate_room_member` are refactored. Dropping those columns without dependency repair could break gift settlement or room moderation. A legacy trigger prevents assigning retired membership again. This is cleanup, **not** full physical erasure of all traces or a completed new membership system.

User accounts, balances, ledger, gifts, rooms and purchases were not erased. Old branches and Git history still retain previous content for rollback.

## New Codex task
Use `feature/membership-reset-20261021` as source baseline. Build fresh VIP/SVIP semantics, user interface, assets and backend independently after auditing existing dependencies; do not copy the retired purchase/entitlement code. Keep Store equipment, gifts and room voice intact. Validate every new function with secure RLS, transactional privileges, and tests.

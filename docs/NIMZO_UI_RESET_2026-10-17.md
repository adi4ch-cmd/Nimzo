# NIMZO Legacy UI Reset (isolated branch)

**Request:** Remove all existing NIMZO UI, without deleting user accounts, wallet balances or backend services.

## Changes already implemented

- `nimzo/lib/app/app.dart`: replaces the original app router/shell with a blank white Flutter canvas. No old Home, Games, Moments, Messages, Profile, Rooms, Store or Login pages are reachable or rendered.
- `nimzo/pubspec.yaml`: removes all original bundled UI image, video/gift, icon and custom-font asset registrations. UI asset binaries therefore are not part of a new Flutter build using this manifest.
- `nimzo/test/ui_reset_test.dart`: verifies that the blank canvas has no navigation, app bar, buttons or old page text.
- Existing `nimzo/lib/main.dart` and Supabase setup are preserved. No SQL migrations, user account edits, deletion, wallet transactions or Vivox configuration changes.

## Important boundaries

The old UI's **source files** still exist as dormant references in the Git tree, because many legacy presentation files contain/re-export providers and state used by backend and existing tests. They are **not mounted by the reset app**, and their assets are no longer registered for packaging. Physically deleting every legacy source file requires extracting and testing the mixed-in non-UI domain/backend code first; it is *not* claimed completed.

The reset app intentionally has no login, navigation, room interaction or other user-facing features. It is a blank slate for an approved replacement UI, **not** a ready-to-ship production app.

All changes are isolated on `feature/nimzo-ui-reset-20261017`, created from saved checkpoint `bd7d15a47135fee292ba237edf6762179264e55d` on `feature/bychance-inspired-ui-20261016`. The previous working UI and main branch remain untouched. No auto-update / production release should be published from this blank branch.

## Verification

Run `flutter analyze --no-fatal-infos --no-fatal-warnings` and `flutter test test/ui_reset_test.dart`. The previous screenshot golden suite intentionally describes the retired UI and is **not** a replacement UI acceptance test. A new design should add fresh tests and only later enable full release validation.

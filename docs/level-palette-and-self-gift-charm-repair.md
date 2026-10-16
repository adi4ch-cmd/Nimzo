# NIMZO Level palette and Charm repair — 2026-10-16

## User-reported issue
Charm level 1 badge was blue, but the tier legend called it Brown. The same mismatch affected Active levels. The screenshot also showed 0 received diamonds despite historical self-gifts.

## Confirmed cause
- Flutter `ProfileLevelScale.color` intentionally rotates base tier colors by [0, 2, 4] for Wealth, Charm, Active, but `LevelsScreen` printed static Wealth color names for all three.
- Supabase `track_lifetime_events` excluded self-gifts from `charm_diamonds`. Current verified gift settlement, however, credits the receiver 45% diamonds even for self-gifts, creating a real earning/progress mismatch.

## Implementation
1. Tier labels now derive from `ProfileLevelScale.paletteIndex`, the same position used for the badge/dot; all 6 tier bands are correctly named on all 3 tabs. Wealth starts Brown, Charm Blue, Active Red.
2. Database function now credits Charm progress for self-gifts using the same verified 45% gift rate.
3. Historic Charm progress is reconciled from already-paid positive `gift_received` and `moment_gift_received` ledger deltas, not estimated from events that might not have credited diamonds.
4. Previous profile Charm counters and original trigger definition are archived privately with RLS. All other user fields, wallets, immutable ledger and gift histories are untouched.

## Live post-migration checks
- 3 profiles backed up.
- Sum of historically credited diamonds restored as Charm progress: 3,195,000.
- Max Charm Level generated: 120 (server's pre-existing 100-diamonds square-step scale, capped at 120).
- Existing wealth progress: 89,755,000; activity progress: 13; both unchanged.
- Wallet totals unchanged (coins 4,386,000; diamonds 0 at verification).
- Retired paid VIP/SVIP states remained inactive.

## QA
- `profile_level_scale_test` checks every color/name against palette rotation.
- `profile_levels_test` tests the actual Level page with Charm, Active and Wealth.
- `supabase/tests/charm_progress_self_gift_repair.sql` performs safe read-only assertions.
- `flutter analyze`, `flutter test` and the native Vivox Android verification workflow must complete before claiming an installable APK.

## Limitations
The colors fix requires an updated Flutter APK. Backend Charm progress is live immediately on refreshed profiles; it does not change wallet balances. The old app may still display stale tier names until updated.

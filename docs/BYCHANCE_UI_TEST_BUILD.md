# NIMZO ByChance-inspired UI test APK checkpoint

This checkpoint triggers the guarded `nimzo-apk-build.yml` workflow from the feature branch.

## Included
Violet/coral styling for Theme, Home, navigation, Profile, Public Profile, Store, Games, Gift catalog, Messages, Moments, Wallet, Login and Onboarding. Current Supabase/Vivox providers and transaction logic are unchanged.

## Explicitly not included
No remote ByChance server API integration; no licensed premium gift animations; no new game engines, VIP/SVIP membership services, admin/backend clone, payout service or Android video calling. Third-party ByChance files are reference assets only, not shipped with NIMZO.

## APK risk
This branch is FORCED to the non-production, temporary development signing path. A newly signed test APK may not install over a previous production-signed APK. User accounts and server-held coin balances are not changed. Do not publish through the app updater.

## Verification
Flutter analyzer, palette regression, all Flutter tests and release-build verifiers must pass before treating its artifact as usable. Device voice, login callbacks and store transactions still require real-phone testing.

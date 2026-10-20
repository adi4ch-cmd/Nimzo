# NIMZO user-provided WillChill 2.3.8 integration media pack

Source: uploaded `WillChill-2.3.8.apks`, `base.apk` integrity verified. The
source filenames and SHA256 digests are recorded in
`nimzo/assets/willchill_premium/catalog.json`.

## Included

- SVIP 1–8 actual artwork; VIP graphics, privilege screens, progress images.
- Gift UI elements, SVGA sending/combo effects, VAP lucky/treasure/coin effects.
- Room entrance, aircraft and crown/orb MP4 animations with verified `vapc` atom.
- Store/Backpack category artwork, frames/bubble/ID-card images, game UI icons.
- Flutter gallery with full-image zoom and original VAP/SVGA playback preview.
- Idempotent, fail-safe router + Store toolbar + `pubspec.yaml` installer.
- SHA256 integrity verification script for extracted media.

## Import into GitHub Codespaces

1. Checkout branch `feature/willchill-premium-assets-20261020`.
2. Upload the accompanying `WillChill_NIMZO_Assets_ONLY_v3.zip` to the repository root in Codespaces.
3. From the repository root run:
   `python3 tools/import_willchill_package.py WillChill_NIMZO_Assets_ONLY_v3.zip`
4. From `nimzo/`, run `flutter pub get`, `flutter analyze`, and `flutter test`.
5. Verify SVIP crown VAP alpha, SVGA effects, Store, backpack, splash/login, Android audio and Vivox coexistence on a physical device before release.

The media remains local and is ignored by Git until redistribution rights are verified.
The branch contains SVIP/VIP preview routes and a Store preview entry point. It is not a complete paid store or gifts settlement release.

## Important limits / not yet production ready

This is an **asset import and working preview integration**, NOT the full live
commercial Store. Embedded UI resources do not contain server-side product IDs,
coin prices, game server, royalty/license enforcement, ownership grants or
membership entitlements. Do not create fictitious buy buttons, silently add
free entitlements or credit/debit coins merely because source files exist.

VAP previews use the existing `flutter_vap_player` plugin and the original
`vapc` files. They must be run on physical devices; packed-alpha files can
look wrong in a generic MP4 player. The existing gifts and coin settlement
logic is deliberately untouched. Before publishing third-party extracted media, verify written permission covering redistribution and commercial use.

## Safe next steps

1. Map each approved premium product to a valid catalog ID, entitlement rule,
   price, duration and target renderer; hold incomplete items as drafts.
2. Hook store equip/unequip to server-verified ownership using current RLS and
   audited RPC flows; never trust client-provided balances.
3. Integrate entrance, badge, frame and bubble into profile and room rendering.
4. Hook gift effects only to **confirmed** room gift events; do not send/debit
   twice and do not autoplay on a mere UI tap.
5. Verify all 8 tiers through a complete entitlement lifecycle and both
   Android/iOS hardware playback before releasing a production APK.

## Current integration status

GitHub branch contains the preview source and local import scripts, but not the extracted third-party media. Use the companion ZIP locally and run automated verification before any release.

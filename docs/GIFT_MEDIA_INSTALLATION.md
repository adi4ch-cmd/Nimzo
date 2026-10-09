# NIMZO original Dragon gift media – verified release path

Only gift functionality is in scope. No database balances, user IDs, prices or VIP state are changed.

- Dragon gift UUID `e1e65664-37f8-4cfd-9640-3bb035723b98`: `nimzo/assets/gifts/dragon_1m.mp4`, SHA-256 `c2b70872477e225d720da7330fc6b5d77b8c6227c00ffc6c6bb558cb4905b2d7`
- Golden Dragon gift UUID `c3f41e6e-68d5-4e56-9253-33421ec18fc3`: `nimzo/assets/gifts/golden_dragon_5m.mp4`, SHA-256 `b9744763526d523dfc6f155beff8510b8481919ad48ec45f778722502ba101ec`

These original H.264/AAC MP4s are 720×1280; lengths approximately 6.06s and 10.80s. The `gift_animation_events` stream is used only after the server settles a gift. The client consults an approved HTTPS media URL before trying a bundled original.

**To get the binaries into GitHub:** Upload the existing `NIMZO_Dragon_Gift_Assets_Patch.zip` to the **root of branch `feature/profile-reference-redesign`** with GitHub's *Add file → Upload files*. A dedicated GitHub Actions workflow checks both SHA-256 values, extracts the originals, updates Flutter's assets list and pushes them to the same branch, removing the temporary ZIP. If that Actions job lacks write permission or branch protection prevents pushing, manually run `python3 tools/import_dragon_gifts.py NIMZO_Dragon_Gift_Assets_Patch.zip` in a Codespace and commit the generated assets. Do not put media in production if permission to redistribute is uncertain.

The `nimzo-gifts-check.yml` workflow performs gift-only analysis and widget tests without producing an APK. The general APK workflow skips commits whose message includes `[gifts-only]`. Trigger a full APK build only **after** media, static checks and widget tests all pass and a real send/receive smoke test is done.

Backend note: `gift_animation_media` was observed empty on 2026-10-09, so approved remote MP4 playback cannot be presumed. The bundled originals are intentionally independent of database media registration. Do not write placeholder URLs to the database.

# NIMZO Store — 91,200 media entry audit and safe import continuation

Source baseline: `feature/dynamic-membership-publisher-20261021`, based on the
integrated 1.0.38 application. No existing profiles, wallets, ownership,
equipped slots, premium membership data or prices are modified by this branch.

## Verified current facts — not a claim of new live sales

- Previous Codex report: 21 APKS packages audited, 91,200 media entries,
  2,715 duplicate groups. The original raw inventory exists as
  `docs/validation/drive-media-audit-20261021.json.gz`.
- **32** original pinned, user-viewable Store media files in
  `nimzo/assets/premium_store/manifest.json` have each passed source SHA-256
  checks on GitHub Actions; these are actual image/SVGA/VAP files, not drawings
  invented in Flutter.
- Supabase has **33** active `nimzo_cosmetic_catalog` items. The unmatched
  `nimzo-original-rides-golden-stars` has **one existing owner**, no approved
  online Store media record, and no pinned original media entry.
  We must **not** delete the record or ownership. This branch hides missing-media
  products from the public Store, preserves the owned item in Backpack and
  disables equipment until a correctly matched original effect is verified.
- Initial metadata-only candidate classification of the original 91k audit
  yields about 70 unique hash entries before physical-media verification.
  This is NOT 70 completed Store products. Many are level/membership status
  effects, preview icons, chat UI states or density variants.
- In particular, the existing candidate report's `rank1.svga` is a leaderboard
  frame, `game_entrance.svga` is a game effect, `svip_online_banner_notice`
  is a membership status asset. None should be silently sold as an ordinary
  Avatar Frame or ride. The strict source scanner filters these.

## Actual implementation in this branch

`tools/stage_apk_store_assets.py` inspects the original nested APK archives
AND the previously extracted Codex media directories. It matches each candidate
against the SHA-256 digest and uncompressed byte size in the source inventory,
checks the SVGA/MP4/image container structure, blocks non-VAP MP4s from being
misrepresented as transparent ride animations, deduplicates existing original
products, and copies qualifying files into private LOCAL staging only.
`tools/test_stage_apk_store_assets.py` covers ZIP nesting, traversal rejection,
checksums, exact extracted-file fallback, category mistakes and container
safety. `.github/workflows/nimzo-store-apk-candidate-audit.yml` reruns these
checks and Store-related Flutter regressions **without building an APK**.

With an existing Codex Codespace terminal (from its repository root):

```bash
git fetch origin feature/store-apk-verified-assets-20261021
git show FETCH_HEAD:tools/stage_apk_store_assets.py > /tmp/nimzo-stage-store.py
python3 /tmp/nimzo-stage-store.py \
  --candidates docs/validation/best-source-candidates-20261021.json \
  --full-audit docs/validation/drive-media-audit-20261021.json.gz \
  --existing nimzo/assets/premium_store/manifest.json \
  --sources-dir /workspaces/nimzo-apk-sources \
  --extracted-dir /workspaces/nimzo-premium-qa \
  --use-full-audit --stage \
  --out nimzo/assets/staged_store_verified \
  --report docs/validation/store-apk-stage-local.json
```

Set the archive and extracted directories to the actual discovered paths.
The script never edits the baseline app, app dependencies, production data,
or wallet; the output must be visually and natively reviewed before being
moved from staging into `premiumCosmetics` and into an authorized active
catalog. Merely creating an inert staging directory is not the same as
publishing a working product.

## Required completion sequence

1. Use Codex's exact extracted folder or original APKS files; do not invent
   them from filenames. Run the script and inspect blocked records.
2. Confirm real user cosmetic category, original asset rights, duplicate
   SHA-256, dimensions, transparency, codecs and optional thumbnail.
3. Flutter `SVGAParser` decode check for every SVGA. For MP4, ffprobe/actual
   native VAP decoding and audio/video synchronization on Android. Image
   overlays must not hide avatars or cover mic controls. Show original
   full-animation preview, never a static substitute.
4. Add only verified files to Flutter's declared asset bundle, stable
   `premiumCosmetics` registry and a matching inactive server catalog ID.
   Audit genuine gift/level/status media separately, never sell a game demo.
5. Verify actual collect/buy, equip, remove, Backpack, room entry and account
   switch; then activate user-approved items with agreed prices, without
   resetting any existing coin/diamond balances.
6. After all outstanding full NIMZO master task features and mandatory tests
   are complete, build the final Android APK once. No premature rebuilds.

Current blocker: Original APK binaries are accessible through connected Drive,
but the Codespace-extracted 9k-file directory has not been mounted as an
executable terminal to this chat. The GitHub-hosted runner does not receive
private Google Drive archive files or private Codespace filesystem bytes.
**No new candidate is described as live or playback-verified without that
last actual-byte/device step.**

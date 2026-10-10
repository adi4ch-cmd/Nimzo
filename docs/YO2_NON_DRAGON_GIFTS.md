# Original Yo2 gifting assets — scope & provenance

**Scope:** The user explicitly requested all non-Dragon gifts. Do not modify Dragon/Golden Dragon videos, IDs, coin prices, ledgers, payouts or VIP/SVIP screens.

Yo2 v1.32.0 user-supplied archives:
- `NIMZO_Yo2_Assets_Part_1_of_2.zip`: SHA-256 `bc3449b2dc0db1db1b7228a36cc64036b0c206e0ebaad4c749bec8ccf229b40e`
- `NIMZO_Yo2_Assets_Part_2_of_2.zip`: SHA-256 `7837f52fac8cc0c28ca8cfb263e618c7e013f9656ad4a3536beeee75e15e9249`

The importer selects **24 original Yo2 gift-specific UI WebP assets** and **7 lucky/super gift SVGAs** (31 assets total). The archives **do not contain Yo2's remotely downloaded animations for individual catalog gifts**, nor a complete, verified Yo2 gift database. Do not invent or claim those assets. The four `lucky_gift_*.svga` files are special lucky effects, not verified animations for the NIMZO gifts, so never assign them to an arbitrary gift ID.

Importer: `python3 tools/import_yo2_gift_assets.py PART1.zip PART2.zip`. It verifies the exact expected asset set, WebP signatures, ZIP CRCs, refuses conflicting overwrites, emits a SHA-256 manifest and registers the Flutter asset directories. Drag-and-drop the **two original ZIP parts** in one GitHub commit at the repository root of `feature/profile-reference-redesign`. The import workflow verifies both whole-archive checksums, installs 31 original gift assets and deletes the temporary upload ZIPs from the branch.

**No APK build** until all required non-Dragon media and gift flows have been reviewed and verified on device. The gift-only analysis/tests workflow does not build an APK.

Legal: The user reports the asset owner authorized reuse; independently retain written license terms before commercial distribution.

# Previous Codex branch audit — 2026-10-23

**Result: no additional recovered exact-kind exact-tier original fills the remaining requested gaps.** Earlier branches preserve generic store art, old membership screen art, numbered medals/emblems, and preview/reference screenshots. Those are not relabeled as missing entrances, bubbles, full profile cards, mic waves, or room backgrounds.

This was a read-only comparison after the parent fetched remote refs. Snapshot HEAD: `72f5832df1e65cf45bdda851abab7708d38b824e`. No checkout, source edit, migration, commit, or build was performed by this audit.

## Search scope

Enumerated all **69 available origin remote refs**, traversed their complete Git trees, and compared media objects to snapshot HEAD. Media scan includes PNG/WebP/JPEG/GIF/SVG, SVGA/PAG, MP4/WebM/MOV, Lottie/Rive and ZIP/APK/APKS without restricting filenames to membership keywords. This covers **35625 ref/media entries** and **313 distinct path/object pairs** that differ from or are absent at HEAD. Read and searched **51 distinct source manifest/inventory/catalog blobs**, deduplicated by Git object. Inspected all **6 additional archive objects**, **214 embedded entries**, with recursive nested archive handling.

Practical bound: current fetched branch-tip trees plus their embedded archives and stored source inventories. This does not claim to enumerate every deleted historical blob, unreachable object, artifact in GitHub Actions, or remote CDN media.

| Explicitly reviewed source branch | Tip commit | Media entries | Different/absent at HEAD |
|---|---|---|---|
| `origin/feature/willchill-premium-assets-20261020` | `f4a971d12b2a` | 1053 | 36 |
| `origin/tools/nimzo-tana-vani-audit-20261020` | `f5365ebe652e` | 640 | 62 |
| `origin/feature/store-apk-verified-assets-20261021` | `b5916838d410` | 1092 | 8 |
| `origin/feature/real-premium-store-assets-integration` | `3042cfa7d472` | 640 | 62 |
| `origin/feature/free-royal-memberships-20261016` | `f6511a2d5fe8` | 293 | 104 |
| `origin/feature/dynamic-membership-publisher-20261021` | `942fbf97e177` | 1092 | 8 |
| `origin/feature/activate-store-from-verified-apk-20261020` | `5ff9b8ff0b73` | 614 | 41 |
| `origin/feature/activate-store-original-cosmetics-20261020` | `5d1cb8d63c59` | 614 | 36 |
| `origin/feature/real-store-room-gifts-20261020` | `a73150bcbefb` | 677 | 62 |
| `origin/integration/nimzo-v3-dynamic-20261021` | `4b989d263192` | 1311 | 0 |

## Candidate findings

- **WillChill premium branch:** original catalog includes SVIP1–8 static `voiceroom_svipN_entry_level_ic.webp`, generic `voiceroom_svip_entry_bg.webp`, default mic wave, store category pictures and membership screen containers. These original media objects are already present at HEAD. The entry-level icons are static badge/banner components, not recovered high-tier entrance animations. Generic `voiceroom_crown_orb_N.mp4` has no demonstrated exact kind/tier assignment; it cannot establish SVIP7/8 entrance provenance merely because a numeric suffix matches.
- **Tana/Vani audit and real-premium-store branches:** additional `props_store_tab_bubble_true.webp`, `props_store_tab_entryefect_true.webp`, Vani `cat_chat_bubbles.png` / `cat_entry.png`, generic frames and room theme category art are recorded in `SOURCE_INVENTORY.json`. They are category illustrations or generic store resources. Their source paths do not establish a missing VIP/SVIP tier. `room_rank_avatar_frame1–3.webp` is room-rank art, not membership level1–3. No exact gap recovered.
- **Free royal membership branch:** `docs/free-royal-memberships-status.md` explicitly says “Original 17 tier-specific SVG emblems and animated native Flutter royal stage,” and “Video-equivalent photorealistic 3D animal/mount/vehicle entrance media and alpha playback are NOT created in this work.” It further says room themes and high-fidelity mic waves are not integrated and cards are previews. VIP1–8 / SVIP1–9 SVGs are custom emblems, not extracted source effects. `hilo/store/royal_1–6.webp` is static royal store art, not the remaining high-tier entrances.
- **Other earlier reference/emblem branches:** `reference/emblems/vip_N.svg` and `svip_N.svg` are custom numbered vector badges, not original APK slot art. A `royal_lion_entry_tier10` migration assigns custom Nimzo code behavior to VIP10; that does not prove an original APK entrance media asset or supply one. Reference screenshots and test goldens are not raw reusable media.
- **Haza legacy membership:** absent-at-HEAD assets are screen UI backgrounds, buttons, tags, and privilege containers. Numbered `ic_vip_tag_N` and `ic_vip_bg_1–4` are not matching requested raw effects or full room wallpapers. No SVIP1/2 mic wave or SVIP full card/bubble family established.
- **Store verified/dynamic membership branches:** manifests point to the same previously audited extracted assets or staged membership selection families. No additional matching original was found beyond the 39 originals the parent has already integrated.
- **Embedded archives:** `NIMZO_Premium_Store_Fix.zip` contains the already-known generic DangLive/WillChill store originals and code; the two room-rocket zips hold six rocket-stage assets; `Nimzo_FINAL_GitHub.zip` is old project source; golden-dragon source/QA archives hold custom dragon work. None establishes the requested missing exact-kind/tier asset.

## Remaining gaps after the branch search

| Requested gap | Fresh branch result |
|---|---|
| VIP7,8,9,10 entrance animations | No additional verified exact-tier original |
| SVIP7,8,9,10 entrance animations | No additional verified exact-tier original |
| SVIP1–10 chat bubbles | No additional verified exact-tier original |
| VIP7–10 chat bubbles | No additional verified exact-tier original |
| Full SVIP1–10 profile-card backgrounds | No additional verified full card; Orii1–6 ornamental strips remain decoration |
| VIP7–10 full profile-card backgrounds | No additional verified exact-tier original |
| SVIP1–2 mic animations | No additional verified exact-tier original |
| Additional membership room backgrounds | No additional verified exact-tier original; existing Tana VIP6 remains valid |

“No additional verified” is bounded to this audit and previous local APK audit. It is not a claim that source apps or their CDN catalogs lack such assets.

## Reproducible artifacts

- `branch-tree-inventory.json`: each remote ref, media paths/Git objects, HEAD equality and source inventory object IDs.
- `branch-source-inventory-matches.json`: read source inventory/catalog blobs and matching lines with refs.
- `branch-candidate-assessments.json`: source asset SHA-256, Git object, refs and truthful role for legacy candidate families; all marked as not filling a requested gap.
- `branch-embedded-zip-inventory.json`: ZIP SHA-256, originating object/refs and every embedded filename/size.

All candidate assets remain in Git; no rejected legacy assets were installed into the app. No Android or build success is claimed.

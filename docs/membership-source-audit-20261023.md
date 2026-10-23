# Exact-kind exact-tier local media audit — 2026-10-23

Read-only audit; no app/source, branch, migrations, commits, network, or Android runtime actions. Previous extraction was reviewed first (`vip-refresh-a/REPORT.md`, inventory, selected files, expanded-store selection/rejections), then every locally present package was freshly scanned including nested APK/ZIP inventories. This report does not assert Android testing or equipping behavior.

## Strong findings

- All 20 avatar-frame slots have genuine original artwork locally. VIP1–5 WillChill `icon_vipN_2.png` are clean empty frames with original baked VIPN labels, NOT sample portraits. VIP6–10 YoHo `vipN_frames.webp` are clean empty frames on wide alpha canvases (use alpha bounds-aware layout). SVIP1–10 Voku `svip_frame_N.png` are clean empty frames with exact original baked SVIPN labels. Every image in all three families was visually inspected. Falla SVIP1–10 additionally supplies clean level-up portrait-frame artwork, accurately recorded as that role.
- WillChill VIP1–5 `icon_vipN_4.png` are clean empty bubbles with tails, no sample text: valid bubble art. `icon_vipN_5.png` contains a baked sample animal portrait: NOT a mic animation. Replace those with genuine Orii `vipN_micwave.svga` for VIP1–6. BGChat provides clean VIP6 chat bubble plus alternatives VIP1,3–5; none for VIP2.
- Orii has exact SVIP1–6 `entrance_svipN.svga`: genuine animated entry banners, visually inspected diagnostic timeline renders. Hafla supplies VIP1–6 animated entry banners; these are banners with runtime slots, not full-screen vehicles.
- Falla `assets/voice/voice_svip7.svga` through `voice_svip10.svga` are genuine circular mic/voice waves. All four decoded and visually inspected diagnostic renders (214x214,20fps,60frames). Orii provides SVIP3–6 waves already source-audited previously. SVIP1–2 no exact wave identified.
- Hilo `mic_svip7–10.svga` are ornate animated THRONE/MIC-SEAT graphics, not mic waves. Preserved for review but excluded from wave slot.
- Orii `profile_card_svip1–6.svga` are animated ornamental TOP STRIPS. Preserved as profile decoration; they do not constitute full profile-card backgrounds. Orii genuine VIP1–6 `vipN_profilecardbg` supplies full original card backgrounds. Generic `vip_card_bg_N` / tier membership-card designs are not silently counted as profile cards.
- Voku VIP1–10 `vip_frame_N.png` embeds sample bust silhouettes, so rejected for raw avatar frames. Voku `vip_entry_N.png`, `vip_mic_N.png`, `vip_profile_N.png` endpoint examples are static privilege icons, NOT actual animations/cards. Voku SVIP frames are different: empty, usable art.

## Remaining bounded gaps

VIP7–10 and SVIP7–10 entrance animations: no verified exact-kind exact-tier entrance animation found in these local inventories. Tier-specific broadcasts (`broadcast_svipN`) are broadcasts, not automatically entrances. Voku high-tier `vip_entry_N` is a static perk symbol. SVIP1–10 and VIP7–10 chat bubbles: no verified tier-specific originals found locally. Full SVIP1–10 profile card backgrounds remain unverified; SVIP1–6 ornamental strips are available separately. Room backgrounds: only original Tana VIP6 `bg_voice_room_vip6_mode.webp` verified from the prior source audit and current bytes; stage source SHA is retained. Room seats, banners, membership-page hero backgrounds and fly-screen banners do not fill this slot.

Missing here means no verified matching original in the audited local files, not absence from source apps or remote catalogs. Filename scans cannot fully resolve opaque/unnumbered resource families.

## Per-tier selected usable slots

| Tier | Avatar frame | Entrance animation | Full profile card | Medal | Nameplate/badge | Chat bubble | Mic animation | Room background |
|---|---|---|---|---|---|---|---|---|
| VIP 1 | yes WillChill | yes Hafla | yes Orii | yes YoHo | yes YoHo | yes WillChill | yes Orii | missing |
| VIP 2 | yes WillChill | yes Hafla | yes Orii | yes YoHo | yes YoHo | yes WillChill | yes Orii | missing |
| VIP 3 | yes WillChill | yes Hafla | yes Orii | yes YoHo | yes YoHo | yes WillChill | yes Orii | missing |
| VIP 4 | yes WillChill | yes Hafla | yes Orii | yes YoHo | yes YoHo | yes WillChill | yes Orii | missing |
| VIP 5 | yes WillChill | yes Hafla | yes Orii | yes YoHo | yes YoHo | yes WillChill | yes Orii | missing |
| VIP 6 | yes YoHo | yes Hafla | yes Orii | yes YoHo | yes YoHo | yes BGChat | yes Orii | yes Tana |
| VIP 7 | yes YoHo | missing | missing | yes YoHo | yes YoHo | missing | missing | missing |
| VIP 8 | yes YoHo | missing | missing | yes YoHo | yes YoHo | missing | missing | missing |
| VIP 9 | yes YoHo | missing | missing | yes YoHo | yes YoHo | missing | missing | missing |
| VIP 10 | yes YoHo | missing | missing | yes YoHo | yes YoHo | missing | missing | missing |
| SVIP 1 | yes Voku | yes Orii | missing | yes Hafla | yes Hafla | missing | missing | missing |
| SVIP 2 | yes Voku | yes Orii | missing | yes Hafla | yes Hafla | missing | missing | missing |
| SVIP 3 | yes Voku | yes Orii | missing | yes Hafla | yes Hafla | missing | yes Orii | missing |
| SVIP 4 | yes Voku | yes Orii | missing | yes Hafla | yes Hafla | missing | yes Orii | missing |
| SVIP 5 | yes Voku | yes Orii | missing | yes Hafla | yes Hafla | missing | yes Orii | missing |
| SVIP 6 | yes Voku | yes Orii | missing | yes Hafla | yes Hafla | missing | yes Orii | missing |
| SVIP 7 | yes Voku | missing | missing | yes Hafla | yes Hafla | missing | yes Falla | missing |
| SVIP 8 | yes Voku | missing | missing | yes Hafla | yes Hafla | missing | yes Falla | missing |
| SVIP 9 | yes Voku | missing | missing | yes Hafla | yes Hafla | missing | yes Falla | missing |
| SVIP 10 | yes Voku | missing | missing | yes Hafla | yes Hafla | missing | yes Falla | missing |

## Artifacts and evidence

- `by-kind-tier-slot.json`: convenient selected index, exact original path, asset SHA-256, source archive entry, package SHA-256 where locally available, dimensions and truthful role.
- `staged-index.json`: all 149 staged candidate records including rejected/alternative roles and animation structure checks.
- `staged/`: original media bytes, untouched alpha. Files ending `.diagnostic.png` / `.sprites.jpg` are clearly named diagnostics; these are not original source files and must not replace the originals.
- `all-package-filename-inventory.json`: 21 locally present archives, 102040 total file entries scanned including all nested APKs, package SHA-256 and all keyword candidates. Previous media-audit additionally includes Lama inventory although the Lama archive is not currently local.
- `avatar-frame-sheet.jpg`, `voku-frame-review-sheet.jpg`, `WillChill-sheet.jpg`, `chat-bubble-candidate-sheet.jpg`: visual role evidence.
- `*-render-sheet.jpg`: diagnostic source timeline frames at 25/50/75%; best populated frame shown. This compositor does not establish actual Flutter/Android rendering. All referenced images and motion state details are recorded in `svga_audit` where decoded.

WillChill/Tana current original assets have per-asset SHA and earlier extraction paths; package archive SHA is null because the originating package is unavailable in `/workspace/nimzo-audit/packages`. No fabricated provenance or cross-tier/kind reassignment.

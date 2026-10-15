# Six realistic gifts — implementation status

User scope replaces Golden Dragon work on 2026-10-15. Golden Dragon's remaining render workflow was cancelled. New branch starts from the latest `feature/profile-reference-redesign` commit `e76a9e69cf5e8a080975c95c5cd4d26eb3ded970`.

**NOT COMPLETE. Four moving car review renders exist, but no accepted six-gift set or final APK exists.** No artificial/procedural substitute has been created. A detailed free CC-BY car model has now been acquired and rendered diagnostically; suitable completed lion/tiger gifts and Android test access remain unavailable. The user's reply “500k coins” authorizes **500,000 coins for each new gift**, not a USD model-purchase budget.

## Implemented foundation

- Reviewed, inactive-only catalog staging migration: `supabase/migrations/20261015215848_stage_six_realistic_gifts.sql`. Generated with Supabase CLI. Not applied to production. New rows have NULL artwork and active=false; no media availability is claimed.
- `GiftVapOverlay`: bundled native VAP-v2 renderer using the actual `flutter_vap_player` 2.1.1 API, muted texture playback, server-event identity/metadata, completion/error/skip handling, startup/playback watchdogs, lifecycle cleanup and an optional fallback callback.
- **The component is not routed into production playback yet.** Existing opaque/SVGA fallback and verified event queues are unchanged. Do not register alpha media as an ordinary MP4 URL: existing `GiftVideoOverlay` is opaque-video playback.
- Real PostgreSQL tests exercise migration staging, replay after future activation, ID/name conflicts and price preservation. Widget tests simulate native callbacks; they do not prove Android decoding or voice coexistence.

## Proposed new catalog identities

| Gift | Proposed UUID | Authorized coin price | Production state |
|---|---|---:|---|
| Red Luxury Supercar | `8b4dfa2b-192e-4c90-89dd-8d9598d142c8` | 500000 | Not inserted |
| Black Luxury Supercar | `bf064182-3921-4e8b-aff1-7fca143470a8` | 500000 | Not inserted |
| Gold Luxury Supercar | `90d1ffac-62a4-4cd7-b8a3-ef298e4207da` | 500000 | Not inserted |
| Blue Luxury Supercar | `d63cfcf1-8b5f-4852-af7b-8ffbd6bb348e` | 500000 | Not inserted |
| Royal Lion | `97a5410c-4e42-411d-b291-fb67186a3bf7` | 500000 | Not inserted |
| Royal Tiger | `f7720b54-9eef-4186-9d37-3db4796a2b67` | 500000 | Not inserted |

Read-only production audit found the existing Sports Car UUID `35e4c570-cb02-4466-ae86-d670b3fb05ab` active at 100000 coins, with no existing six-gift-name matches. That entry stays unchanged. Existing users, wallets, IDs, historical gift rows, ledgers, VIP/SVIP and Vivox code are untouched. The latest six-gift instruction permits additional gifts but does not authorize replacing the older catalog.

## Asset budget and current free render work

The user approved **$0** for assets/subscriptions. No purchases are permitted or made.

A detailed Car Concept model from Khronos glTF Sample Assets is downloaded under its specific CC BY 4.0 license, with a CC0 Poly Haven HDRI. See [asset attribution](../../tools/realistic_gifts/ATTRIBUTION.md) for pinned sources, hashes, exclusions and modifications. Existing authored wheel assemblies are animated; no primitive car substitute is used.

`tools/realistic_gifts/car_scene.py` creates four independently colored Blender projects, real rolling/steering/driving motion, reflections, headlights, camera movement and volumetric tire haze. Corrected diagnostic renders exist. The first full four-color render/encode run [38816339177](https://github.com/adi4ch-cmd/Nimzo/actions/runs/38816339177) succeeded: 240 actual RGBA frames per color, 8 seconds at 360×640/30 fps. Its full-motion visual review exposed a finite shadow-plane edge and inactive authored quaternion steering. Those previews were rejected for production. The corrected [run 38818436101](https://github.com/adi4ch-cmd/Nimzo/actions/runs/38818436101) removes the plane, uses actual quaternion steering, aligns heading to a 24-m-radius driving arc with a real braking/hero stop, orbits the camera and widens its framing. Low-resolution review renders are not accepted production masters.

The CC-BY Running Tiger file was imported and a real Cycles diagnostic rendered. Its 3,204-vertex mesh and texture-only fur do not meet the requested quality; it was rejected. Its one Run animation also lacks the requested walk/roar. Inspected free lion candidates were stylized, low-poly or a cub and were rejected. A promisingly named Royal Lion listing also appears stylized in its thumbnail and is not accepted. Noncommercial tiger rigs were rejected.

## Paid alternatives researched — not purchased

These are candidate listings, **not verified incorporated assets or final licensing recommendations**. No marketplace account/purchase/download entitlement was provided.

| Candidate | Advertised suitability | Access and remaining checks |
|---|---|---|
| [Crossblade CB16 concept sports car](https://superhivemarket.com/products/concept-sports-car-with-rig-and-full-interior) | Generic non-brand model, full rig/interior, suspension, PBR, Blender/Cycles; page lists $25 | Paid download needed. Inspect current Blender compatibility, four recolors, wheel/steering rig and commercial render rights before acceptance. |
| [VFX Grace animated male lion](https://www.vfxgrace.com/product/male-lion-animated-vfx-grace/) | Blender, groom/rig, walking; five-animation listing includes roar and lists $560 | Paid access needed. Correct team/license tier and permission for the virtual-gift use case must be established. |
| [VFX Grace Bengal tiger](https://www.vfxgrace.com/product/bengal-tiger-animation-blender-3d-model/) | Blender/Cycles, rig, fur, facial controls, 4K UDIM maps; listing $500 | Paid access needed. Inspect included motions, compatibility, license and render cost. |
| [Blendkit male lion](https://www.blendkit.com/asset-gallery-detail/12948b42-e942-4f25-808d-8b0dc71c2d30/) | Twelve actions, Rigify-based rig, 4K maps | Full Plan entitlement required. Inspect actual fur/close-up quality; listing is not art acceptance. |
| [Blendkit realistic Bengal tiger](https://www.blendkit.com/asset-gallery-detail/633b9d6b-b518-47f1-b921-5ac4cdfda497/) | Advertised rigged/animated realism | Access, license and actual rendered quality remain unverified. |

Prices are observed listing amounts on 2026-10-15, not a purchase quote or user authorization. See [VFX Grace license](https://www.vfxgrace.com/3d-models-license/), [Superhive royalty-free license](https://superhivemarket.com/page/royalty-free-license), [Blendkit licenses](https://www.blendkit.com/docs/licenses/). VFX Grace's terms have specific virtual-world, AI-use and sharing restrictions; broad “commercial” wording alone does not establish permission for this task. A suitable alternative or explicit applicable permission may be needed.

Purchased .blend/model/texture files must stay in appropriately licensed private storage; NIMZO's repository is public. Rendering rights do not automatically authorize publishing raw models. Source-project handoff must follow the acquired license.

## Rendering and acceptance work still blocked/pending

1. The free car model is acquired and documented. Suitable free commercially usable lion/tiger models with convincing fur and walk/roar animation remain unresolved; do not substitute the rejected candidates.
2. Produce four unmistakable metallic car colors with wheel rotation, driving, lights, camera, smoke and entrance/exit; animate walking/looking/roaring/exiting for both furred animals. Each 8–12 seconds, at least 30 fps. No static-picture or primitive fallback.
3. Render actual RGBA sequences and derive moving MP4 previews, properly packed Android alpha, thumbnails and licensed source projects. Visually inspect and reject weak results. First complete moving four-car renders and CPU alpha checks have run; corrected car review renders and encoding have passed. Only a rejected tiger diagnostic exists; complete animal gift renders remain pending.
4. Establish approval of all six actual previews, then implement accepted format-aware UUID media mappings, lifecycle/fallback/queue tests and a reviewed activation migration. Do not charge for absent/unaccepted media.
5. Test native alpha on two real Android phones, including sender/recipient room events, true settlement and Vivox mic/audio continuity. No adb executable or USB Android devices are attached here. Mock callback tests are not those tests.
6. Only after all six are approved, integrated and tested: run one final APK build, verify package `io.nimzo.app`, signing/installability/content/hash, publish to a real accessible location, and check the direct download. No final build or APK URL is claimed now.

The earlier GitHub Releases upload endpoint returned HTTP401 despite Git pushes working. Final APK publication may require GitHub Actions' release token or another real authorized hosting path; verify the upload and download before providing a link. Do not invent an APK URL.

## Checks executed for this foundation

- Full Flutter 3.47.7/Dart 3.13.5 analysis: exit 0, no issues.
- Full Flutter test suite: **338 passed**, exit 0, including eight native-VAP callback/lifecycle tests (not device tests).
- Five PostgreSQL staging tests: passed in an isolated local PG17 container, after observing all five fail against the empty migration.
- New widget tests first failed for the absent component, then passed. Additional lifecycle, delayed initialization and 15-second playback-watchdog tests passed.
- Independent code review found no concrete blocker in the migration or renderer; the additional lifecycle/watchdog coverage gaps were filled.
- No production SQL writes or migration application, real device/voice test, final APK build or APK upload has occurred. Licensed free car downloads, diagnostics and four complete review animations have occurred. Corrected review renders and encoding have passed.
- The VAP platform interface 2.1.0 is pinned as a test dependency. Resolving the baseline's already-declared SVGA/VAP dependencies filled 19 missing lock entries; no previously locked package version changed. CI uses the repository's 3.47.6 Flutter pin.

A separate foundation-check workflow runs only analysis/tests and disposable database checks; it never generates an APK. The final APK gate remains unmet.

## CGI verification details

- Real FFmpeg round-trip regression passed, including every one of 240 decoded RGBA frames matching the source, soft alpha, actual packed H.264 decoding and rejection of an opaque replacement master.
- Corrected packed Blender source was opened and evaluated at six moving frames: heading/velocity dot product above 0.999999, measured turning radius above 20 m, changing front-wheel quaternion steering and cumulative rolling rotation; no mesh shadow catcher remains. This does not substitute for visual motion review or Android QA.
- Initial publication failed because the runner lacked FFmpeg; the workflow now installs it explicitly. Corrected publication run 38818505195 succeeded. The public prerelease contains 30 assets, including four actual MP4 previews, four packed source/RGBA ZIPs, four VAP candidates, posters and room composites. All 30 release assets were downloaded and matched their published sizes and available API SHA-256 digests; the 29 payloads also match SHA256SUMS.txt. Every source ZIP was opened and contains a real Blender project plus 240 RGBA frames and required alpha/poster files.

Review render limitations: 360×640 and 8 samples are intended to assess real model/motion/color first. Stochastic volume alpha is visibly noisy in diagnostics and needs higher-sample master rendering before production acceptance. No claim of premium final quality or Android certification is made.

BlenderKit free-only searches were also checked directly through its public API: 33 lion search results and 15 tiger search results, including unrelated props/statues. Frostwhisk, Simba and Terna thumbnails were inspected and rejected as cartoon/stylized. Full result identities and advertised licenses are retained in animal-candidate-audit.json; no candidate was accepted or purchased.

## Actual published review downloads

[Review release — four cars, NO APK](https://github.com/adi4ch-cmd/Nimzo/releases/tag/car-review-38818436101)

| Color | Actual moving MP4 | Desktop light-room alpha composite | Packed Blender/RGBA/source ZIP |
|---|---|---|---|
| Red | [Preview](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/red-car-preview.mp4) | [Room composite](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/red-car-room-light.mp4) | [Source](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/red-car-render-source.zip) |
| Black | [Preview](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/black-car-preview.mp4) | [Room composite](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/black-car-room-light.mp4) | [Source](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/black-car-render-source.zip) |
| Gold | [Preview](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/gold-car-preview.mp4) | [Room composite](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/gold-car-room-light.mp4) | [Source](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/gold-car-render-source.zip) |
| Blue | [Preview](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/blue-car-preview.mp4) | [Room composite](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/blue-car-room-light.mp4) | [Source](https://github.com/adi4ch-cmd/Nimzo/releases/download/car-review-38818436101/blue-car-render-source.zip) |

Each preview was downloaded and probed: H.264, 360×640, 240 frames, 30 fps, 8.000 seconds. Every color was visually inspected at six decoded video frames; colors are visibly distinct. Room videos are CPU composites, not native Android recordings. Lossless RGBA comparison covered all 960 actual source frames across the four gifts. The Android VAP candidates are 736×640 packed streams displaying a 360×640 effect; decoded alpha mean absolute error was below 0.026 on the checked 0–255 sample for all colors.

The per-color source ZIP includes actual .blend, all RGBA PNGs, lossless FFV1/BGRA master, VAP candidate, transparent PNG/WebP artwork and verification report. The specific asset license and attribution accompany the handoff. Source ZIPs are published, not merely an unrendered script.

These are unapproved low-resolution review renders, with visibly noisy low-sample haze. High-resolution/high-sample masters, suitable free animals, in-app credits/mappings/activation, native Android alpha, real gift-event/settlement checks, two-device Vivox tests and final APK remain outstanding. No final APK was built or uploaded.

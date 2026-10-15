# Six realistic gifts — implementation status

User scope replaces Golden Dragon work on 2026-10-15. Golden Dragon's remaining render workflow was cancelled. New branch starts from the latest `feature/profile-reference-redesign` commit `e76a9e69cf5e8a080975c95c5cd4d26eb3ded970`.

**NOT COMPLETE. No six-gift footage or final APK exists yet.** No artificial/procedural substitute has been created. Licensed production models and Android test access are not available in this environment. The user's reply “500k coins” authorizes **500,000 coins for each new gift**, not a USD model-purchase budget.

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

## Model acquisition research — not purchased or downloaded

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

1. Obtain legitimate downloadable professionally modeled/rigged car, lion and tiger projects and document rights for NIMZO's paid virtual-gift use.
2. Produce four unmistakable metallic car colors with wheel rotation, driving, lights, camera, smoke and entrance/exit; animate walking/looking/roaring/exiting for both furred animals. Each 8–12 seconds, at least 30 fps. No static-picture or primitive fallback.
3. Render actual RGBA sequences and derive moving MP4 previews, properly packed Android alpha, thumbnails and licensed source projects. Visually inspect and reject weak results. No six-gift renders have run yet.
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
- No production SQL writes or migration application, licensed model download, six-gift render, real device/voice test, final APK build or APK upload has occurred.
- The VAP platform interface 2.1.0 is pinned as a test dependency. Resolving the baseline's already-declared SVGA/VAP dependencies filled 19 missing lock entries; no previously locked package version changed. CI uses the repository's 3.47.6 Flutter pin.

A separate foundation-check workflow runs only analysis/tests and disposable database checks; it never generates an APK. The final APK gate remains unmet.

# NIMZO v3 Games, Moments and Events presentation selection

Date: 2026-10-21. Scope: presentation only; no builds, backend writes or new game engines.

## Evidence and source decisions

Read `/workspace/nimzo-audit/media-audit.json` (91,200 audited media entries across available packages) and the master task. Compared games entries across HART, StarChat, Hafla, Voku, Hilo, Falla, YoHo and other packages. Extracted and visually inspected complete image candidates in an external contact sheet at `/workspace/nimzo-audit/games-selection-review.jpg`. No private data or credentials extracted.

| Source package | Exact archive path | SHA256 | Audit compatibility | Decision |
| --- | --- | --- | --- | --- |
| HART-0.2.73.apks | `base.apk!/res/drawable-xxhdpi-v4/fruit_bottom_bg.webp` | `fa131174211e46ab357379dcce0f73772971f5550427fe727b2240f52824770e` | Flutter image | Candidate only; not imported |
| HART-0.2.73.apks | `base.apk!/res/drawable-xxhdpi-v4/ic_spin_wheel_loop_fruit_bg.webp` | `ca8db538ff9fa30132b39e55ebef8f59c304f91b288e0b00ee5a0d4275196e16` | Flutter image | Candidate only; not imported |
| Hafla-1.7.2.apks | `base.apk!/res/drawable/icon_game_domino.png` | `d9568abd2db2d0422e4994680fdfa27de68bb069cf0a4b84c8f68e8094ad8a20` | Flutter image | Candidate only; not imported |
| Hafla-1.7.2.apks | `base.apk!/res/drawable/icon_game_ludo_1.png` | `a92510578bd6ae24f9c86669071b4e23710c3106d9d2c320b7dbb5256bdf00e1` | Flutter image | Candidate only; not imported |
| StarChat-8.41.3.apks | `base.apk!/res/drawable-xhdpi-v4/bg_chat_room_lucky_fruit_pan.webp` | `d02f1fae9cb72a3e8bc54b0723a0f151b384fd0e8b0f44f7f93f3a8f884eb726` | Flutter image | Candidate only; not imported |
| StarChat-8.41.3.apks | `base.apk!/res/drawable-xhdpi-v4/chat_room_icon_lucky_fruit.webp` | `8aea231faad781d50c627cda6f175ce98759a6443dc4ea2adaddfc4319250ede` | Flutter image | Candidate only; not imported |
| Voku-1.1.7.apks | `base.apk!/assets/flutter_assets/assets/images/banner/banner_game_static.png` | `f5fcc74878b07d8d9817cb43e09f26484751ce2950362f02f674ceb2aff2b5ac` | Flutter image | Candidate only; not imported |

HART's fruit wheel ring and StarChat's fruit icon are self-contained art. Their panel strips/nine-patches are partial UI requiring layout assembly. Hafla's Domino/Ludo icons are complete but describe engines NIMZO does not ship. Voku's BIG WIN strip is decorative rather than a complete game cover. All audited candidates still carry “owner permission asserted; per-asset scope unverified”; no new redistribution clearance is inferred from package access.

Selected final presentation: preserve the seven already integrated reference game covers and their existing approval classification; use newly authored original NIMZO vector fruit reels/wheel covers for the two existing server-backed fruit engines. This avoids reusing Lucky 77 art for Fruit Party. New covers are static catalog illustrations, do not imply tested gameplay or display invented results. No candidate APK artwork is newly shipped by these changes.

Moments uses real author/profile/post/image/like/comment/gift actions and original NIMZO identity art. No sample people, feed items or counts are introduced. The editor and feed receive emerald/white surfaces, legible headings and compact actions.

Events no longer uses cropped phone screenshot reward campaign banners as an automatic fallback. Loading, failed requests and no-active-events are explicit. Active campaign artwork/title/subtitle comes only from `nimzoEventBannersProvider`, preserving server timing, active status and revision refresh filtering. Pull-to-refresh and retry are available. No reward, entitlement or eligibility is invented.

## Verification requested centrally

- `flutter analyze lib/features/games/games_catalog_screen.dart lib/features/events/events_screen.dart lib/features/moments/moments_screen.dart test/social_catalog_presentation_test.dart test/home_events_reference_test.dart`
- `flutter test test/social_catalog_presentation_test.dart test/home_events_reference_test.dart test/game_catalog_test.dart test/game_layout_test.dart test/moment_delete_confirmation_test.dart test/moment_editor_retry_test.dart`
- `dart format` parsed all changed Dart sources successfully; `git diff --check` clean for this scope.

No APK/AAB/IPA generated. Widget checks do not prove device gameplay, network media decode or settlement.

## Functional limits retained honestly

- Fruit Party and Fruit Wheel retain existing server coin contracts; secure production settlement/device operation is outside these presentation checks.
- Four existing practice titles retain free-chip practice. Other boards remain previews, with no asserted real-money/coin engines.
- Event campaign targets now navigate only to explicit supported local destinations (`/games`, `/store`, `/ranking`, `/levels`, `/honors`, `/daily-checkin`). Unknown, external, query-bearing and wallet targets remain informational and receive no CTA. New destination types still require a supported client route/action contract.
- No new APK art was approved/published, no fabricated campaigns were staged, and no real user data or balances were mutated.

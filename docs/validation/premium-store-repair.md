# Store and membership layout repair

Base: `feature/willchill-premium-assets-20261020` (`f4a971d`). The older default branch and documented profile branch do not contain the app shown in the supplied screenshots. Store media and its ID registry are reused from `feature/real-store-room-gifts-20261020` (`a73150b`), matching the deployed Supabase catalog.

The Store previously selected artwork by category and variant. Several imported items share variant 0, so Portrait 3, Gold Circle and original frames rendered the same generic crown. Imported IDs now resolve to pinned original PNG, SVGA or VAP assets. The grid uses real static posters or a decoded SVGA frame; the full preview replays the original animation. Collected/equipped IDs and server claim/equip calls are retained. Own Profile and Me avatars render the imported frame instead of only a colored ring.

VIP and SVIP stay at `/vip` and `/svip`; Store and Backpack stay at `/store` (including `?bag=1`). The extra premium asset-gallery entry is removed. Membership screens follow the supplied video: full-width tier backgrounds, a large VIP crest, SVIP podium, 3-column Identification and Exclusive privilege grids, progress artwork and a fixed bottom status/price bar. The horizontal tier strip reveals the selected tier automatically, including on narrow screens. Account data uses the existing session-scoped Supabase provider, so account switches invalidate membership results; expired VIP remains inactive.

## Fresh uploaded APKS audit

[Source APKS](https://drive.google.com/file/d/17XKAYV4FSQJ7b7WpUs1HYXUKLAqp3_Zf/view), version 2.3.8, SHA256 `6bb4f02977ec1453895c986ec0ca3a507cb60296fb97baedbd49af16b940d6f8`. Extracted 2,208 original media files from `base.apk`: 1,896 PNG, 243 WebP, 15 JPG, 6 GIF, 27 MP4, 19 SVGA and 2 audio files. The xxhdpi split contains no additional named VIP/SVIP resources. All 441 previously imported records were reverified directly against this fresh APK.

Some SVIP badges, nameplates and headwear seen in the [reference video](https://drive.google.com/file/d/1bNtN_q86vmnAEwus94bWyzFg03UvRZFJ/view) are **not embedded in the APK**. Its `SVipConfList` response model contains `cover`, `coverV2`, `backgroundImg`, `privilegeResourceMap` and `privilegeList`, supplied by `user/svip/conf/info`. The app initializes its six privilege resource records with empty strings, then fills them from that response. The uploaded installer does not include downloaded app-cache files. Missing tier-specific images therefore use a clear outline icon instead of inventing original artwork. VIP 1–5 use their exact bundled crests/cards; VIP 6/7 have fewer bundled resources and use the bundled generic VIP emblem where a dedicated crest is absent.

The supplied Drive Tana/Vani archive was also inspected: 195 gift/effect resources, 88 Store resources and 51 membership resources, including XML/UI components. The SHA256 inventory is in `drive-media-audit.json`. These are not 334 saleable gifts/products; existing catalog IDs and settlement effects are preserved.

## Remaining complete resources

The 32 pinned cosmetic products are reused by their deployed IDs; decorative APK icons are not treated as saleable products. Shared visual equipment comes from `nimzo_store_visual_equipment`, which checks active users, active catalog items and ownership on the server. Categories must match the pinned registry before rendering. Failed appearance requests do not block joining a room or using its controls. Store ownership, prices and gift settlement rules are unchanged.

The active gift catalog was read again: Sports Car, Hall of Fame, Dragon Throne, Ice Fire Phoenix and Holy Tiger already have their bundled/private-gateway playback paths. The complete Tana Birthday Cake SVGA was found, but the matching server gift is inactive. It remains in the source audit rather than silently reactivating a retired gift or substituting a chest effect for a rocket. No new gift was activated by this presentation change.

## Verification

- Source inventory: all 441 bundled WillChill files passed SHA256 verification, including SVIP 1–8 and VIP 1–7 artwork.
- Every pinned Store asset and thumbnail exists and is declared in the Flutter asset bundle.
- Latest targeted checks: **50 tests passed** (39 Store/membership/room/gift checks plus 11 profile checks).
- Targeted widget tests cover actual Store/Backpack media, full preview media, real Portrait 3 SVGA decoding, all membership tiers at 320dp and 1.8x text, VIP/SVIP routes, expired VIP, and existing Store contracts.
- Reviewed rendered screenshots: [Store](../ui/premium-store-repair/store.webp), [VIP](../ui/premium-store-repair/vip.webp), [SVIP](../ui/premium-store-repair/svip.webp). Store screenshots use test-only catalog fixtures; actual server inventory remains authoritative.
- Additional equipment tests check the real RPC boundary, reject unknown IDs/category mismatches, exercise server-backed removal, show speaking-only waves and skip historical ride entries. Room reconnect and 320/360/390dp room walkthrough fixtures isolate the newly consumed equipment/member streams.
- Analyzer on changed Store/premium/profile/room files: no errors or warnings; existing style infos remain.
- Earlier full suite, before the additional room-equipment integration: 403 passed, 7 failed. The failures are listed below; the suite is not green. Games catalogs, walkthrough fixtures and older screenshot comparisons remain outside this repair. No golden baselines were overwritten.

- `clone_constraints_test.dart: All seven requested game boards stay represented`
- `remaining_visual_qa_test.dart: remaining reference surfaces have reviewed phone screenshots`
- `tingle_video_ui_test.dart: walkthrough surfaces and privilege navigation fit 320.0dp`
- `tingle_video_ui_test.dart: walkthrough surfaces and privilege navigation fit 360.0dp`
- `tingle_video_ui_test.dart: walkthrough surfaces and privilege navigation fit 390.0dp`
- `reference_preview_test.dart: approved boards and real empty home remain visually stable`
- `master_visual_preview_test.dart: room overlay visual previews`

## Release limits

Supabase's existing `purchase_normal_vip` function currently raises `VIP and SVIP have been retired`. The bottom bar reads prices/duration from `normal_vip_catalog` and honestly displays purchases as unavailable; no fake Buy action is enabled. SVIP progress reads the actual cycle cents and server thresholds, and is never synthesized from the selected preview tier. No database mutations or entitlement grants were needed. No APK was built or published. Native VAP playback, Android device rendering, room voice/Vivox, and installation/signing require the existing verified Android release pipeline and device QA. This source change fixes presentation and item media resolution; it does not introduce a membership purchase/upgrade service or change server privileges. The 32 pinned complete cosmetics also render on room and profile surfaces: avatar frames, speaking-only mic waves, owner room backgrounds/banners, chat bubbles, profile cards, ID frames, badges and newly joined member rides. Backpack removal calls the existing server unequip RPC and refreshes visual equipment. Entrance playback ignores historical members, drops stale pending work on account/room changes and respects reduced-motion settings. Native Android playback still requires device verification.

## Delivery

Review branch: `fix/premium-store-integration`, based on `feature/willchill-premium-assets-20261020`. Screenshots are synthetic review fixtures, with no real account details. Source ZIP and the 2,208-file original-media extraction are also available as local artifacts. The user explicitly approved publishing the source, assets and screenshots to the public repository. The uploaded root ZIP matches the delivered 66-entry archive byte-for-byte (SHA256 cee4d39c2471e147308953309e171f7fea603c136cf76d20919308fba471a8c8). Source review targets `feature/willchill-premium-assets-20261020`, which contains the app and bundled assets used by this repair; the current `main` branch has an older app and the uploaded ZIPs. The ZIP is retained there. Applying only this patch to that older app would omit required dependencies and resources. No APK has been built or published.

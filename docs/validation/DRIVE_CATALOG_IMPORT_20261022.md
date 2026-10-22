# Drive catalog import — 22 October 2026

Owner requested extracting and activating gifts and Store items from supplied Drive APKs. This batch preserves every existing product, ownership row and wallet balance.

Selected originals (manifest records archive SHA256, Drive ID, nested APK path and exact original media SHA256):

- WithU 1.6.5: Gift Shower (7,500 coins), complete 79-frame SVGA.
- YoHo 5.48.40: Magic Genie (15,000 coins), complete 90-frame SVGA.
- BGChat 3.0.6: Amethyst, Azure, Orchid and Crimson Crown avatar frames (10,000 coins each).
- Bazmi 1.0.8: Rose, Violet and Gold ID plates (5,000 coins each).

New Store items have lifetime ownership. These are decorative cosmetics, not membership or moderation privileges. Gifts use existing checked settlement and receiver payout rules. No gift or Store wallet operation is performed during import.

Rejected candidates: Ahlan coupleBigHeart exceeds the existing 256-sprite preflight bound (339 sprites); Hafla bay_buy_ring is a notification banner; DangLive cp-nest and profile-id-frame duplicate existing bundled products; BGChat agency/host frames display role labels. None is added under a misleading name or category.

Host verification uses the real flutter_svga 0.0.13 renderer, confirms every frame index, validates resource presence, captures every frame, checks nonblank and changing pixels, and produces exact-animation thumbnails. All nine pass the application's production `validateRenderableMedia` limits. Thumbnails are static previews; all nine full media files remain SVGA animations.

Reproduce originals:

```
python3 tools/import_drive_catalog.py /workspace/nimzo-audit/packages /workspace/nimzo-audit/media-audit.summary.json
cd nimzo
flutter test test/drive_catalog_preflight_test.dart test/drive_catalog_render_test.dart --concurrency=1
cd ..
python3 tools/finalize_drive_catalog.py <successful-render-log> /tmp/nimzo-drive-rendered
```

Publication requires separate Android emulator renderer evidence, HTTPS hash paths, correct response MIME, byte lengths and hash readback. The Android harness is isolated from accounts, wallets and voice. It does not publish a NIMZO APK. Activation must retain the existing strict publication triggers; device timestamps cannot be inferred from host tests. Full physical-device and authenticated purchase QA are separate from this media verification.

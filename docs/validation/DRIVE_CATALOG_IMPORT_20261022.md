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

## Live activation and results

Migration `20261022190130_activate_verified_drive_gifts_store.sql` applied successfully to project `kvqvlpozqokwarovwmwv`. Readback confirms both new gifts and all seven new Store items active with approved SVGA publications: **7 active gifts total, 45 active Store products total**. Existing wallets, ownership, equipped rows and original catalog records retain identical aggregate hashes before/after. No production purchase, gift send or wallet debit was performed by QA.

- Host full regression: **553 passed** after the equipped ID plate fit correction; analyzer has **0 errors/warnings, 59 existing informational lints**.
- Python guards: **19 passed**.
- Actual additive migration in a new disposable clone: preserves prior fixture wallet/ledger/ownership, both gifts settle and replay, all seven Store products purchase/replay/equip with lifetime ownership. Total fictional debit exactly77,500; no duplicate debit.
- All **18** public Storage objects pass HTTPS, response MIME, byte size and SHA256 readback.
- Android35 x86_64 emulator: all nine media render tests passed every frame at18:55:47.906975Z. First workflow39834701067 failed afterward because preview archive collection assumed the wrong app cache path; that failure is retained in the proof JSON. Collector now derives application ID from built metadata and finds the actual preview directory.
- Source/backend CI for media commit0529578 passed: https://github.com/adi4ch-cmd/Nimzo/actions/runs/39834700753

The temporary JWT/nonce-protected Storage importer was sealed to HTTP410 immediately after uploading18 immutable objects; its deployed second version has no credentials or upload logic. Storage RLS grants no client writes to the new bucket. Source provenance and caller-independent SHA verification remain in the manifest and readback evidence.

The catalog uses remote publications supported by the existing dynamic client. Equipped ID plate scaling is corrected in updated Flutter source; that client improvement requires a subsequent app build. No new distributed NIMZO APK was built in this batch. Android renderer proof uses an isolated test application, without authentication, wallet operations or Vivox. Physical-device authenticated end-to-end purchase testing remains unverified.

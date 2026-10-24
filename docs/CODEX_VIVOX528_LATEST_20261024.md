# Codex handoff — NIMZO voice-enabled Android QA from existing Codespace SDK

**Scope:** NIMZO room/profile premium fixes, 10 mic seats, and a real Vivox 5.28.0 Android build. **SDK exists only in the owner's Codespace, not in the public repository.**

## Inputs already known

- Repository: `adi4ch-cmd/Nimzo`
- Source branch: `feature/falla-levels-v142-20261024`, including merged PRs #47, #48 and #49
- Original Codespace working directory: `/workspaces/Nimzo`
- Possible SDK ZIP: `/workspaces/Nimzo/com.custom.android.vivox.vivoxCoreAndroidSdk-5.28.0.zip`
- Build helper: `tools/build_codespace_vivox_dynamic.py`
- Desired output: private `~/NIMZO_VOICE_QA_APK/`; no public release without further validation
- Version from current source: `nimzo/pubspec.yaml` (currently 1.0.43+143); never hardcode a downgrade

## Execute within the existing Codex Codespace

Do **not** delete, reset, clean or overwrite existing Codespace changes, caches or ZIP files. Preserve local uncommitted work. Use an isolated detached worktree, as the existing helper does.

```bash
cd /workspaces/Nimzo
git status --short
git fetch --no-tags origin feature/falla-levels-v142-20261024
git show origin/feature/falla-levels-v142-20261024:tools/build_codespace_vivox_dynamic.py > /tmp/nimzo-vivox-current.py
python3 /tmp/nimzo-vivox-current.py --check-sdk-only
```

The builder auto-searches the existing archive or extracted tree. If that archive is located elsewhere:

```bash
python3 /tmp/nimzo-vivox-current.py --check-sdk-only --sdk-root /absolute/path/to/SDK.zip
```

The preflight validates the *actual* `Vxc.h`, matching 5.28.0 AAR, and ARM64 `libvivox-sdk.so`; it cannot be replaced by a NO_VIVOX stub or a fake success.

## Before any package build

- Honor `release/acceptance.json` and `tools/verify_prebuild_acceptance.py`. The latest committed acceptance still has `build_authorized: false`; do not falsify evidence or bypass this gate.
- Bring the accepted evidence in sync with the current source and finish remaining owner tasks before final APK: exact-tier VIP/SVIP media gaps, real Store/gift activation and authenticated device acceptance.
- Ensure the selected branch includes 10 seats (5+5) in Flutter and the already-applied Supabase migration. Never re-run the same live migration.
- Run Flutter analyzer plus `test/room_seat_repository_test.dart`, `test/room_profile_premium_layout_test.dart`, `test/room_user_sheet_test.dart`, `test/profile_content_test.dart` and `test/voice/vivox_voice_service_test.dart`.

**Only when the prebuild acceptance genuinely passes:**

```bash
python3 /tmp/nimzo-vivox-current.py
```

The helper copies native Vivox code in an isolated worktree, compiles an ARM64 APK, requires actual ELF libraries within it, writes source SHA + SHA256 checksums, and saves the build privately under `~/NIMZO_VOICE_QA_APK/`.

## Validation before declaring complete

On an Android device, confirm installation/cold start (no black/blocked screen), OAuth sign-in, microphone runtime permission, two logged-in users in the same room, speaking/listening both directions, mute, 10-seat layouts, mic nameplates without overflow, mini/full profile, Store/VIP equipped assets, wired/Bluetooth headset, background/reconnect, and Gift/VAP/SVGA playback.

SDK packaging alone **does not** establish working voice calls. Record failures and fix them rather than declaring success. Do not upload the proprietary SDK to a public GitHub Release, commit its ZIP/AAR/.so, remove saved user accounts, or delete other Codex work.

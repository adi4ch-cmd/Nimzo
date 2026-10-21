# NIMZO Codespace Vivox Android Test Build (21 October 2026)

**Status:** A Codespace-local build path, NOT a completed APK. The owner reports the proprietary Vivox SDK is already in the GitHub Codespace.

## Why GitHub Actions did not see the SDK

The SDK files stored inside the Codespace's filesystem are **not present** in hosted GitHub Actions runners. The older build workflow expected a ZIP at a GitHub Release tag (`vivox-5.28.0`) that currently responds 404. **Do not interpret this as the Codespace SDK being absent**, and do not upload the proprietary SDK to a public GitHub Release or commit it.

The original working tree has unrelated Codex changes and must not be cleaned or reset. The new script creates a **detached temporary Git worktree** from the Dynamic Update branch and scans for Vivox 5.28.0 headers, AAR and native library under the Codespace filesystem. All native SDK integration occurs in that isolated worktree.

## In the existing Nimzoo Codespace terminal

Run these commands from within the existing NIMZO repository:

```bash
git fetch origin feature/dynamic-content-sync-20261021
git show FETCH_HEAD:tools/build_codespace_vivox_dynamic.py > /tmp/nimzo-vivox-build.py
python3 /tmp/nimzo-vivox-build.py --check-sdk-only
python3 /tmp/nimzo-vivox-build.py
```

**Optional only if automatic SDK scanning fails:**

```bash
VIVOX_SDK_ROOT=/absolute/path/to/vivox-sdk python3 /tmp/nimzo-vivox-build.py
```

This requires Git, Python 3, Java, Flutter and the Android SDK installed in the Codespace. It tests the active source, includes OAuth Android callback, builds **arm64 voice-enabled QA APK**, validates native Vivox bridge and library packaging, records the source commit and SHA256, and saves output under:

`~/NIMZO_VOICE_QA_APK/`

The output remains **private in the Codespace**; there is no automatic SDK upload, public release, or production install.

**Safety:** The script never executes `git reset --hard`, `git clean`, SDK commits or a production SQL write. Running `git fetch` and creating a detached worktree do not overwrite uncommitted project files. If the SDK is present but at an unexpected path, provide `VIVOX_SDK_ROOT`. If a needed toolchain is absent, the script fails visibly rather than publishing an unverified build.

## Acceptance checks before production

1. APK checksum and native ARM64 `libvivox_bridge.so` / `libvivox-sdk.so` present (handled by script).
2. Android installs/starts without black screen and stays in foreground after cold start and logout/login. **Not verified by code generation alone.**
3. Test real two-user, 10-mic voice room, headset Bluetooth/wired mic, reconnect, app background/foreground and Vivox server token.
4. Test server-approved MP4/VAP/SVGA after verified Gift send; audio synchronization, transparency, room fullscreen, Rocket thresholds.
5. Test Dynamic Store purchase, equipment, reconnect, a paid item with real approved media, offline sync and secure no-double-charge behavior.
6. Retire unneeded staging from `FEATURES.lock.json` intentionally, but preserve real Voice/Store/Gift/Room contracts.
7. Prefer spare Android device. The QA APK has the same Android package ID and **development signing**, which may conflict with an installed app's signature. **Do not uninstall a working app or erase local data just to install the QA APK** without protecting the user data first.

Final Android/iOS production release, signing, VIP/SVIP rebuild and approved media publication are separate gates.

**GitHub PR:** https://github.com/adi4ch-cmd/Nimzo/pull/40

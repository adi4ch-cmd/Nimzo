#!/usr/bin/env python3
"""Private Google Drive Vivox 5.28.0 -> NIMZO Android ARM64 voice QA APK.

Run on a fresh temporary checkout with Flutter/Android installed, e.g. Colab.
Never commit or upload the proprietary SDK to the PUBLIC NIMZO GitHub repo.
A QA APK is not proof that authenticated voice calls work on two devices.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import zipfile

from build_codespace_vivox_dynamic import configure_android, sdk_location, verify_apk, run
from validate_vivox_sdk import validate_sdk

ROOT = Path(__file__).resolve().parents[1]
ANDROID_SDK_SHA256 = "c30f6caf08184874a7daecc2f9c670df099fa504265dc08b51859e287a38d75f"
ANDROID_SDK_SIZE = 636302182
PART_PATTERN = re.compile(r"^android-vivox-5\.28\.0\.zip\.part[0-9]{3}$")
QA_CHECKS = ("gifts", "memberships", "store_backpack", "room_rocket",
             "progression", "dynamic_audit", "dynamic_models", "dynamic_sync",
             "financial_security", "source_tests")


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_qa_authorization(root: Path) -> None:
    """Explicit QA authorization; NEVER substitute for final-release acceptance."""
    record = json.loads((root / "release/acceptance.json").read_text())
    if record.get("qa_build_authorized") is not True:
        raise ValueError("Owner has not authorized a QA APK")
    if record.get("qa_open_blockers") != []:
        raise ValueError("Owner QA acceptance still has open blockers")
    checks = record.get("qa_checks") or {}
    for name in QA_CHECKS:
        state = checks.get(name, {})
        if state.get("status") != "PASS" or not state.get("evidence"):
            raise ValueError("Missing recorded QA evidence: " + name)
    if not (root / "nimzo/lib/features/rooms/domain/room.dart").is_file():
        raise ValueError("NIMZO Flutter source missing")
    room = (root / "nimzo/lib/features/rooms/domain/room.dart").read_text()
    if "static const count = 10;" not in room:
        raise ValueError("Current approved room design must have 10 seats")
    print("Existing owner QA authorization: PASS (not final-release authorization)")


def reconstruct_sdk(parts_dir: Path, target_zip: Path) -> None:
    """Verify *every* part plus the original entire 636 MB source checksum."""
    manifest_path = parts_dir / "NIMZO_Vivox_parts_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    parts = manifest.get("parts")
    if (manifest.get("source_filename") !=
            "com.custom.android.vivox.vivoxCoreAndroidSdk-5.28.0.zip"
            or manifest.get("source_size_bytes") != ANDROID_SDK_SIZE
            or manifest.get("source_sha256") != ANDROID_SDK_SHA256
            or not isinstance(parts, list) or len(parts) != 4):
        raise ValueError("SDK split manifest does not match validated owner source")
    whole = hashlib.sha256()
    written = 0
    with target_zip.open("wb") as output:
        for index, entry in enumerate(parts):
            name = entry.get("name", "")
            if (not PART_PATTERN.fullmatch(name)
                    or name != f"android-vivox-5.28.0.zip.part{index:03d}"):
                raise ValueError(f"Unexpected Vivox ZIP part at index {index}")
            file = parts_dir / name
            if not file.is_file():
                raise FileNotFoundError(f"Missing private SDK part: {name}")
            if file.stat().st_size != entry["bytes"]:
                raise ValueError(f"Wrong part size: {name}")
            digest = hashlib.sha256()
            with file.open("rb") as src:
                for chunk in iter(lambda: src.read(4 * 1024 * 1024), b""):
                    digest.update(chunk)
                    whole.update(chunk)
                    output.write(chunk)
                    written += len(chunk)
            if digest.hexdigest() != entry["sha256"]:
                raise ValueError(f"SDK part checksum mismatch: {name}")
            print(f"PASS {name}: {entry['bytes']} bytes")
    if written != ANDROID_SDK_SIZE or whole.hexdigest() != ANDROID_SDK_SHA256:
        raise ValueError("Complete Vivox Android SDK SHA-256 mismatch")
    with zipfile.ZipFile(target_zip) as archive:
        if archive.testzip() is not None:
            raise ValueError("Vivox Android SDK ZIP integrity failed")
    print("Original vendor SDK ZIP byte-for-byte validated:", whole.hexdigest())


def verify_assets(apk: Path, root: Path) -> None:
    """Fail closed if 683 original level badges or voice binaries are absent."""
    with zipfile.ZipFile(apk) as package:
        entries = set(package.namelist())
        for category, top in (("wealth", 270), ("charm", 270), ("active", 140)):
            for level in range(top + 1):
                relative = f"assets/falla_levels/{category}/{level}.webp"
                apk_key = "assets/flutter_assets/" + relative
                if apk_key not in entries or package.read(apk_key) != (
                        root / "nimzo" / relative).read_bytes():
                    raise ValueError(f"Missing original Falla level asset: {relative}")
        print("Original Falla wealth/charm/active artwork: PASS (683 files)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parts-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--verify-sdk-only", action="store_true")
    args = parser.parse_args()
    if not ROOT.joinpath("nimzo/pubspec.yaml").is_file():
        parser.error("Run from a fresh checkout of NIMZO repository")
    temp_dir = Path(tempfile.mkdtemp(prefix="nimzo-private-vivox-"))
    archive = temp_dir / "official-vivox-5.28.0.zip"
    reconstruct_sdk(args.parts_dir.expanduser(), archive)
    sdk_root, header, aar, native = sdk_location(str(archive), temp_dir / "extracted")
    evidence = validate_sdk(header, aar, native, "arm64-v8a")
    print("Official release AAR + Stripped/Release ARM64 native SDK: PASS")
    print("Native SHA256:", evidence["native_sha256"])
    if args.verify_sdk_only:
        return

    verify_qa_authorization(ROOT)
    for tool in ("flutter", "java", "git"):
        if not shutil.which(tool):
            raise RuntimeError(f"Missing Android/Flutter build tool: {tool}")
    if not (os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")):
        raise RuntimeError("ANDROID_HOME / ANDROID_SDK_ROOT must be configured")
    run(sys.executable, "tools/verify_nimzo_feature_lock.py", cwd=ROOT)
    run(sys.executable, "tools/test_native_auth_storage_key_policy.py", cwd=ROOT)
    run(sys.executable, "tools/verify_willchill_premium.py", cwd=ROOT)
    configure_android(ROOT, sdk_root, aar)
    app = ROOT / "nimzo"
    (app / "test/widget_test.dart").unlink(missing_ok=True)
    run("flutter", "pub", "get", "--enforce-lockfile", cwd=app)
    run("flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings", cwd=app)
    run("flutter", "test", "--reporter", "expanded",
        "test/startup_bootstrap_contract_test.dart",
        "test/voice/vivox_voice_service_test.dart",
        "test/room_seat_repository_test.dart",
        "test/room_profile_premium_layout_test.dart",
        "test/room_user_sheet_test.dart",
        "test/profile_content_test.dart",
        "test/store_live_contract_test.dart",
        cwd=app)
    run("flutter", "build", "apk", "--release",
        "--target-platform", "android-arm64", cwd=app)

    apk = app / "build/app/outputs/flutter-apk/app-release.apk"
    if not apk.is_file():
        raise RuntimeError("Flutter did not generate the voice-enabled APK")
    info = verify_apk(apk)
    verify_assets(apk, ROOT)
    run(sys.executable, "tools/verify_willchill_apk_bundle.py", str(apk),
        cwd=ROOT)
    run(sys.executable, "tools/test_shared_preferences_abi_policy.py", cwd=ROOT)
    run(sys.executable, "tools/verify_shared_preferences_android_abi.py",
        str(apk), cwd=ROOT)

    match = re.search(r"(?m)^version:\s*([0-9.]+\+[0-9]+)\s*$",
                      (app / "pubspec.yaml").read_text())
    if not match:
        raise ValueError("Unknown NIMZO pubspec version")
    output = args.output_dir.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    commit = os.popen(f'git -C "{ROOT}" rev-parse HEAD').read().strip()
    filename = f"NIMZO_{match.group(1)}_VIVOX528_ARM64_VOICE_QA.apk"
    target = output / filename
    shutil.copy2(apk, target)
    (output / "SHA256SUMS.txt").write_text(
        f"{info['sha256']}  {filename}\n")
    report = {
        "app_version": match.group(1),
        "source_commit": commit,
        "sdk_source_sha256": ANDROID_SDK_SHA256,
        "native_library_sha256": evidence["native_sha256"],
        "artifact_sha256": info["sha256"],
        "size_bytes": info["size_bytes"],
        "sdk_packaged": True,
        "checks": "Flutter analyzer; unit tests; native ELF; 683 assets; WillChill assets; SharedPreferences ABI",
        "android_device_startup": "NOT YET VERIFIED",
        "real_two_user_audio": "NOT YET VERIFIED",
        "signing": "DEVELOPMENT SIGNATURE — QA ONLY",
        "final_production_acceptance": "NOT SATISFIED",
    }
    (output / "BUILD_REPORT.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Voice QA APK BUILT (not verified on physical phone):", target)
    print("SHA256:", info["sha256"])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, zipfile.BadZipFile) as error:
        print("VOICE QA BUILD FAILED:", error, file=sys.stderr)
        sys.exit(1)

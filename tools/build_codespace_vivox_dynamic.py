#!/usr/bin/env python3
"""Build a NIMZO Android voice QA APK from the SDK already in a Codespace.

Run: python3 tools/build_codespace_vivox_dynamic.py
Optionally: VIVOX_SDK_ROOT=/absolute/sdk/folder python3 tools/build_codespace_vivox_dynamic.py
No proprietary SDK media or APK is committed, pushed, or published by this script.
A clean detached worktree protects existing, possibly uncommitted Codex work.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile


REPO_BRANCH = "feature/falla-levels-v142-20261024"
A = "{http://schemas.android.com/apk/res/android}"
TOOLS = "{http://schemas.android.com/tools}"
ET.register_namespace("android", A[1:-1])
ET.register_namespace("tools", TOOLS[1:-1])


def run(*args: str, cwd: Path | None = None) -> None:
    print("+", " ".join(str(arg) for arg in args), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, check=True)


def output(*args: str, cwd: Path | None = None) -> str:
    return subprocess.check_output(list(map(str, args)), cwd=cwd, text=True).strip()


# The SDK 5.28.0 ZIP contains Debug, Release, and Stripped native libraries.
# Gradle's AAR packages the Stripped/Release ARM64 binary, so link CMake to
# that EXACT binary. Copy only the matching subset into an isolated temp dir.
SDK_COMPONENTS = (
    "include/Vxc.h",
    "include/VxcTypes.h",
    "include/VxcErrors.h",
    "include/VxcRequests.h",
    "include/VxcResponses.h",
    "include/VxcEvents.h",
    "aar/sdk-release.aar",
    "Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so",
)


def _sdk_components_on_disk(folder: Path) -> dict[str, Path] | None:
    if not folder.is_dir():
        return None
    visited = 0
    for directory, dirs, names in os.walk(folder):
        dirs[:] = [d for d in dirs if d not in {
            ".git", ".gradle", ".dart_tool", "build", "node_modules",
            ".next", ".pub-cache", "Pods"
        }]
        visited += len(names)
        if visited > 250000:
            print("Vivox SDK directory search limit:", folder, flush=True)
            return None
        if "Vxc.h" not in names:
            continue
        include = Path(directory)
        if include.name != "include":
            continue
        root = include.parent
        selected = {relative: root / relative for relative in SDK_COMPONENTS}
        if all(path.is_file() for path in selected.values()):
            return selected
    return None


def _sdk_components_in_zip(archive: zipfile.ZipFile) -> dict[str, str] | None:
    available = set(archive.namelist())
    # The real archive is rooted at vivox-sdk-5.28.0.34030.504b30c0/SDK/.
    # Require ALL components to share one single SDK root, not mixed releases.
    roots = {
        name[:-len("include/Vxc.h")]
        for name in available
        if name.endswith("/SDK/include/Vxc.h")
    }
    matching = [
        {relative: prefix + relative for relative in SDK_COMPONENTS}
        for prefix in roots
        if all(prefix + relative in available for relative in SDK_COMPONENTS)
    ]
    if len(matching) > 1:
        raise RuntimeError("Multiple complete SDK roots found in ZIP; select one")
    return matching[0] if matching else None


def sdk_location(explicit: str | None, tmp: Path) -> tuple[Path, Path, Path, Path]:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit).expanduser().resolve())
    else:
        for candidate in (
            "/tmp/vivox/android", "/tmp/vivox",
            "/workspaces/nimzo-premium-qa", "/workspaces/Nimzo",
            "/workspaces/nimzo", "/workspaces", "/opt/vivox",
            str(Path.home() / "vivox"), str(Path.home() / "sdk"),
        ):
            p = Path(candidate)
            if p.exists() and p not in candidates:
                candidates.append(p)
        for folder in (Path("/workspaces/Nimzo"), Path("/workspaces/nimzo"),
                       Path("/workspaces/nimzo-premium-qa"), Path.home()):
            sdk_zip = folder / "com.custom.android.vivox.vivoxCoreAndroidSdk-5.28.0.zip"
            if sdk_zip.is_file() and sdk_zip not in candidates:
                candidates.append(sdk_zip)

    for candidate in candidates:
        sdk_tree = tmp / "vivox-selected-sdk"
        selected: dict[str, Path] | None = None
        if candidate.is_file() and candidate.suffix.lower() == ".zip":
            try:
                with zipfile.ZipFile(candidate) as archive:
                    members = _sdk_components_in_zip(archive)
                    if members is None:
                        continue
                    for relative, name in members.items():
                        info = archive.getinfo(name)
                        if info.file_size == 0 or info.file_size > 160 * 1024 * 1024:
                            raise ValueError("Unexpected SDK member size: " + name)
                        dest = sdk_tree / relative
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        with archive.open(name) as src, dest.open("wb") as dst:
                            shutil.copyfileobj(src, dst, length=4 * 1024 * 1024)
                selected = {relative: sdk_tree / relative for relative in SDK_COMPONENTS}
            except (zipfile.BadZipFile, OSError) as exc:
                print("Unable to read SDK ZIP:", candidate, exc, flush=True)
                continue
        elif candidate.is_dir():
            found = _sdk_components_on_disk(candidate)
            if found:
                for relative, src in found.items():
                    dest = sdk_tree / relative
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dest)
                selected = {relative: sdk_tree / relative for relative in SDK_COMPONENTS}

        if selected:
            header = selected["include/Vxc.h"]
            aar = selected["aar/sdk-release.aar"]
            native = selected["Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so"]
            # One ARM64 .so only, preventing ambiguous CMake globs.
            print("Selected Vivox SDK ZIP/folder:", candidate, flush=True)
            print("SDK staging root (temporary, private):", sdk_tree, flush=True)
            with aar.open("rb") as sdk_archive:
                aar_digest = hashlib.file_digest(sdk_archive, "sha256").hexdigest()
            print("AAR SHA256:", aar_digest, flush=True)
            return sdk_tree, header, aar, native

    raise RuntimeError(
        "A consistent Vivox SDK 5.28.0 release bundle was not found. "
        "Need six include headers, sdk-release.aar and "
        "Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so. "
        "Set VIVOX_SDK_ROOT to the original ZIP or extracted SDK folder. "
        "No existing files were deleted."
    )


def configure_manifest(android: Path) -> None:
    path = android / "app/src/main/AndroidManifest.xml"
    tree = ET.parse(path)
    manifest = tree.getroot()
    required = (
        "android.permission.INTERNET",
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS",
        "android.permission.BLUETOOTH",
        "android.permission.BLUETOOTH_CONNECT",
        "android.permission.REQUEST_INSTALL_PACKAGES",
    )
    present = {el.get(A + "name") for el in manifest.findall("uses-permission")}
    for permission in required:
        if permission not in present:
            ET.SubElement(manifest, "uses-permission", {A + "name": permission})
    app = manifest.find("application")
    if app is None:
        raise RuntimeError("Android application manifest missing")
    app.set(A + "label", "NIMZO Voice QA")
    app.set(A + "icon", "@drawable/nimzo_launcher")
    app.set(TOOLS + "replace", "android:name")
    activities = app.findall("activity")
    if not activities:
        raise RuntimeError("Flutter main Android activity missing")
    main = activities[0]
    main.set(A + "name", "io.nimzo.app.MainActivity")
    main.set(A + "exported", "true")
    main.set(A + "launchMode", "singleTask")
    have_oauth = any(
        data.get(A + "scheme") == "io.nimzo.app"
        for intent in main.findall("intent-filter")
        for data in intent.findall("data")
    )
    if not have_oauth:
        intent = ET.SubElement(main, "intent-filter")
        ET.SubElement(intent, "action", {A + "name": "android.intent.action.VIEW"})
        ET.SubElement(intent, "category", {A + "name": "android.intent.category.DEFAULT"})
        ET.SubElement(intent, "category", {A + "name": "android.intent.category.BROWSABLE"})
        ET.SubElement(intent, "data", {
            A + "scheme": "io.nimzo.app", A + "host": "login-callback",
        })
    if not any(
        x.get(A + "name") == "flutter_deeplinking_enabled"
        for x in main.findall("meta-data")
    ):
        ET.SubElement(main, "meta-data", {
            A + "name": "flutter_deeplinking_enabled", A + "value": "false",
        })
    existing = [x for x in app.findall("provider")
                if x.get(A + "authorities") == "io.nimzo.app.apk_updates"]
    if not existing:
        provider = ET.SubElement(app, "provider", {
            A + "name": "androidx.core.content.FileProvider",
            A + "authorities": "io.nimzo.app.apk_updates",
            A + "exported": "false",
            A + "grantUriPermissions": "true",
        })
        ET.SubElement(provider, "meta-data", {
            A + "name": "android.support.FILE_PROVIDER_PATHS",
            A + "resource": "@xml/nimzo_apk_paths",
        })
    xml = android / "app/src/main/res/xml/nimzo_apk_paths.xml"
    xml.parent.mkdir(parents=True, exist_ok=True)
    xml.write_text(
        '<paths xmlns:android="http://schemas.android.com/apk/res/android">'
        '<cache-path name="nimzo_updates" path="nimzo_updates/" /></paths>\n'
    )
    tree.write(path, encoding="utf-8", xml_declaration=True)


def configure_android(work: Path, sdk_root: Path, aar: Path) -> None:
    app = work / "nimzo"
    android = app / "android"
    run("flutter", "create", "--no-pub", "--platforms=android",
        "--project-name", "nimzo", ".", cwd=app)
    # Flutter create may regenerate lockfile: retain the branch's original.
    run("git", "restore", "--", "nimzo/pubspec.yaml", "nimzo/pubspec.lock", cwd=work)
    run(sys.executable, "../tools/configure_android_gradle.py", "android", cwd=app)

    native = app / "native/vivox/android"
    java = android / "app/src/main/java/io/nimzo"
    java_app = java / "app"
    java_voice = java / "vivox"
    cpp = android / "app/src/main/cpp"
    draw = android / "app/src/main/res/drawable"
    libs = android / "app/libs"
    for directory in (java_app, java_voice, cpp, draw, libs):
        directory.mkdir(parents=True, exist_ok=True)
    for kt in (android / "app/src/main/kotlin").rglob("MainActivity.kt"):
        kt.unlink()  # Only generated worktree Android activity, not original repo.
    for name in ("MainActivity.java", "NimzoUpdate.java"):
        shutil.copy2(native / name, java_app / name)
    shutil.copy2(native / "NimzoVivox.java", java_voice / "NimzoVivox.java")
    for name in ("vivox_bridge.cpp", "CMakeLists.txt"):
        shutil.copy2(native / name, cpp / name)
    shutil.copy2(native / "nimzo_launcher.xml", draw / "nimzo_launcher.xml")
    shutil.copy2(app / "assets/brand/nimzo_purple_gold.png",
                 draw / "nimzo_brand_icon.png")
    shutil.copy2(native / "proguard-rules.pro",
                 android / "app/proguard-rules.pro")
    shutil.copy2(aar, libs / "vivox-sdk-5.28.0.aar")
    configure_manifest(android)

    gradle = android / "app/build.gradle.kts"
    if not gradle.is_file():
        raise RuntimeError("Expected generated Android Kotlin Gradle script")
    s = gradle.read_text()
    s, n = re.subn(r'namespace\s*=\s*"[^"]+"',
                   'namespace = "io.nimzo.app"', s, count=1)
    if n != 1:
        raise RuntimeError("Unable to configure package namespace")
    s, n = re.subn(r'applicationId\s*=\s*"[^"]+"',
                   'applicationId = "io.nimzo.app"', s, count=1)
    if n != 1:
        raise RuntimeError("Unable to configure Android application ID")
    # Vivox proprietary code stays in this worktree, never gets git added.
    root = sdk_root.resolve().as_posix().replace('"', '\\"')
    s += f'''
// Local Codespace-only Vivox 5.28.0 SDK. Never commit the SDK or AAR.
android {{
    defaultConfig {{
        externalNativeBuild {{
            cmake {{
                arguments.add("-DVIVOX_SDK_ROOT={root}")
            }}
        }}
    }}
    externalNativeBuild {{
        cmake {{
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }}
    }}
    compileOptions {{
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }}
    buildTypes {{
        getByName("release") {{
            isMinifyEnabled = false // test-only; signing remains development
            isShrinkResources = false
            proguardFiles("proguard-rules.pro")
        }}
    }}
}}
dependencies {{
    implementation(files("libs/vivox-sdk-5.28.0.aar"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}}
'''
    gradle.write_text(s)


def verify_apk(apk: Path) -> dict[str, str | int]:
    with zipfile.ZipFile(apk) as zip_file:
        if zip_file.testzip() is not None:
            raise RuntimeError("Compiled APK archive integrity check failed")
        names = set(zip_file.namelist())
        required = [
            "lib/arm64-v8a/libvivox_bridge.so",
            "lib/arm64-v8a/libvivox-sdk.so",
        ]
        for path in required:
            if path not in names:
                raise RuntimeError(f"Native voice library absent in APK: {path}")
            if zip_file.read(path)[:4] != b"\x7fELF":
                raise RuntimeError(f"Native library invalid: {path}")
    return {
        "size_bytes": apk.stat().st_size,
        "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", default=os.getenv("VIVOX_SDK_ROOT"),
                        help="Vivox SDK unpacked directory or SDK ZIP")
    parser.add_argument("--branch", default=REPO_BRANCH)
    parser.add_argument("--output-dir",
                        default=str(Path.home() / "NIMZO_VOICE_QA_APK"))
    parser.add_argument("--check-sdk-only", action="store_true")
    args = parser.parse_args()
    source = Path(output("git", "rev-parse", "--show-toplevel")).resolve()
    tmp_parent = Path(tempfile.mkdtemp(prefix="nimzo-codespace-voice-qa-"))
    sdk_root, header, aar, native = sdk_location(args.sdk_root, tmp_parent)
    run(sys.executable, str(source / "tools/validate_vivox_sdk.py"),
        "--header", str(header), "--aar", str(aar), "--native", str(native),
        "--abi", "arm64-v8a", cwd=source)
    if args.check_sdk_only:
        print("SDK READINESS PASS. No code changes, APK build or upload.")
        return
    run(sys.executable, "tools/verify_prebuild_acceptance.py", cwd=source)
    for cmd in ("git", "flutter", "java"):
        if not shutil.which(cmd):
            raise RuntimeError(f"{cmd} not found in Codespace PATH")
    if not os.getenv("ANDROID_HOME") and not os.getenv("ANDROID_SDK_ROOT"):
        raise RuntimeError("Android SDK toolchain is not configured in Codespace")
    run("git", "fetch", "--no-tags", "origin", args.branch, cwd=source)
    work = tmp_parent / "worktree"
    run("git", "worktree", "add", "--detach", str(work), "FETCH_HEAD",
        cwd=source)
    commit = output("git", "rev-parse", "HEAD", cwd=work)
    print("Build source:", commit)
    print("Original Codespace worktree is untouched:", source)
    run(sys.executable, "tools/verify_nimzo_feature_lock.py", cwd=work)
    run(sys.executable, "tools/verify_prebuild_acceptance.py", cwd=work)
    configure_android(work, sdk_root, aar)
    app = work / "nimzo"
    run("flutter", "pub", "get", "--enforce-lockfile", cwd=app)
    run("flutter", "analyze", "--no-fatal-infos", "--no-fatal-warnings",
        "lib/app/app.dart", "lib/features/gifts/verified_gift_broadcast.dart",
        "lib/features/store/store_live_catalog.dart",
        "lib/features/rooms/presentation/room_screen.dart", cwd=app)
    run("flutter", "test",
        "test/startup_bootstrap_contract_test.dart",
        "test/dynamic_content_sync_test.dart",
        "test/store_paid_purchase_test.dart",
        "test/verified_gift_broadcast_test.dart",
        "test/room_reconnect_test.dart",
        "test/voice/vivox_voice_service_test.dart",
        "test/room_seat_repository_test.dart",
        "test/room_profile_premium_layout_test.dart",
        "test/room_user_sheet_test.dart",
        "test/profile_content_test.dart", cwd=app)
    run("flutter", "build", "apk", "--release",
        "--target-platform=android-arm64", cwd=app)
    apk = app / "build/app/outputs/flutter-apk/app-release.apk"
    if not apk.is_file():
        raise RuntimeError("Flutter did not produce the APK")
    result = verify_apk(apk)
    out = Path(args.output_dir).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    pubspec = (app / "pubspec.yaml").read_text()
    match = re.search(r"(?m)^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$", pubspec)
    if match is None:
        raise RuntimeError("Cannot determine NIMZO app version from pubspec.yaml")
    target = out / f"NIMZO_{match.group(1)}_VIVOX528_ARM64_QA_{commit[:10]}.apk"
    shutil.copy2(apk, target)
    (out / "SHA256SUMS.txt").write_text(
        f"{result['sha256']}  {target.name}\n")
    (out / "SOURCE_SHA.txt").write_text(f"{commit}\n")
    (out / "BUILD_REPORT.json").write_text(json.dumps({
        "source_commit": commit, "build_branch": args.branch,
        "voice_sdk": "local Codespace SDK; not uploaded",
        "sdk_aar_sha256": hashlib.sha256(aar.read_bytes()).hexdigest(),
        "output": str(target), "apk": result,
        "device_test": "PENDING — not verified on a connected phone",
        "signing": "development/test only",
    }, indent=2) + "\n")
    print("\nAndroid voice QA APK built and verified:", target)
    print("SHA256:", result["sha256"])
    print("No release was published; check on an Android device before release.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError, ValueError) as exc:
        print("NIMZO CODESPACE VOICE BUILD BLOCKED:", exc, file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env python3
"""Configure generated Flutter Android host project for Nimzo Firebase Cloud Messaging.

Does NOT configure Firebase Auth or modify Supabase/Vivox. No admin keys or user
config files are committed to Git; JSON comes from an Actions secret or local file.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys

PACKAGE = "io.nimzo.app"
PROJECT_ID = "nimzo-1f296"
PLUGIN_VERSION = "4.5.0"


def add_to_plugins(path: Path, line: str) -> None:
    content = path.read_text(encoding="utf-8")
    if "com.google.gms.google-services" in content:
        return
    match = re.search(r"(?m)^plugins\s*\{", content)
    if not match:
        raise RuntimeError(f"No plugins block in {path}")
    content = content[: match.end()] + "\n    " + line + content[match.end() :]
    path.write_text(content, encoding="utf-8")


def ensure_package(build_file: Path, kotlin: bool) -> None:
    text = build_file.read_text(encoding="utf-8")
    if kotlin:
        pattern = r'(\b(namespace|applicationId)\s*=\s*)["\'][^"\']+["\']'
        replacement = lambda m: m.group(1) + '"' + PACKAGE + '"'
    else:
        pattern = r'(\b(namespace|applicationId)\s+)["\'][^"\']+["\']'
        replacement = lambda m: m.group(1) + '"' + PACKAGE + '"'
    text, count = re.subn(pattern, replacement, text)
    if count < 2:
        raise RuntimeError("Expected namespace and applicationId in generated Android Gradle file")
    build_file.write_text(text, encoding="utf-8")


def fix_main_activity(android: Path) -> None:
    main_files = list((android / "app/src/main").rglob("MainActivity.kt"))
    if not main_files:
        main_files = list((android / "app/src/main").rglob("MainActivity.java"))
    if len(main_files) != 1:
        raise RuntimeError(f"Expected one generated MainActivity, found {len(main_files)}")
    source = main_files[0]
    text = source.read_text(encoding="utf-8")
    text, count = re.subn(r"(?m)^package\s+[^\s;]+", f"package {PACKAGE}", text, count=1)
    if count != 1:
        raise RuntimeError("Unable to change MainActivity package")
    dest = android / "app/src/main" / ("kotlin" if source.suffix == ".kt" else "java") / Path(*PACKAGE.split(".")) / source.name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text, encoding="utf-8")
    if source != dest:
        source.unlink()


def ensure_notification_permission(android: Path) -> None:
    path = android / "app/src/main/AndroidManifest.xml"
    text = path.read_text(encoding="utf-8")
    if "android.permission.POST_NOTIFICATIONS" in text:
        return
    text, count = re.subn(
        r"(<manifest\b[^>]*>)",
        r'\1\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        text,
        count=1,
        flags=re.DOTALL,
    )
    if count != 1:
        raise RuntimeError("Unable to find Android manifest root element")
    path.write_text(text, encoding="utf-8")


def run(root: Path, data: str) -> None:
    config = json.loads(data)
    if config.get("project_info", {}).get("project_id") != PROJECT_ID:
        raise RuntimeError("Firebase project does not match NIMZO project")
    clients = config.get("client") or []
    if not any(c.get("client_info", {}).get("android_client_info", {}).get("package_name") == PACKAGE for c in clients):
        raise RuntimeError("Firebase Android client package does not match io.nimzo.app")
    android = root / "android"
    if (android / "settings.gradle.kts").exists():
        settings = android / "settings.gradle.kts"
        add_to_plugins(settings, f'id("com.google.gms.google-services") version "{PLUGIN_VERSION}" apply false')
    else:
        settings = android / "settings.gradle"
        add_to_plugins(settings, f"id 'com.google.gms.google-services' version '{PLUGIN_VERSION}' apply false")
    if (android / "app/build.gradle.kts").exists():
        app = android / "app/build.gradle.kts"
        add_to_plugins(app, 'id("com.google.gms.google-services")')
        kotlin = True
    else:
        app = android / "app/build.gradle"
        add_to_plugins(app, "id 'com.google.gms.google-services'")
        kotlin = False
    ensure_package(app, kotlin)
    fix_main_activity(android)
    ensure_notification_permission(android)
    target = android / "app/google-services.json"
    target.write_text(json.dumps(config, separators=(",", ":")) + "\n", encoding="utf-8")
    print("NIMZO FCM Android configured: Gradle plugin, package ID, Android 13 permission and Firebase client JSON")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=Path.cwd(), help="Flutter project root")
    p.add_argument("--config-file", type=Path, help="Local path to google-services.json")
    args = p.parse_args()
    if args.config_file:
        data = args.config_file.read_text(encoding="utf-8")
    else:
        data = os.getenv("NIMZO_GOOGLE_SERVICES_JSON", "")
    if not data:
        sys.exit("Missing Firebase config: set NIMZO_GOOGLE_SERVICES_JSON or pass --config-file")
    run(args.root, data)


if __name__ == "__main__":
    main()

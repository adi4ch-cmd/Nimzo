#!/usr/bin/env python3
"""Install the two owner-approved Dragon videos from their supplied ZIP.

Usage: python3 tools/import_dragon_gifts.py /path/to/NIMZO_Dragon_Gift_Assets_Patch.zip
No production database, catalog prices, IDs or account balances are modified.
"""
import hashlib
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "nimzo"
FILES = (
    "nimzo/assets/gifts/dragon_1m.mp4",
    "nimzo/assets/gifts/golden_dragon_5m.mp4",
)
MAX_BYTES = 40_000_000

def install(archive):
    with zipfile.ZipFile(archive) as z:
        invalid = z.testzip()
        if invalid:
            raise ValueError(f"ZIP integrity failed: {invalid}")
        extracted = {}
        for name in FILES:
            info = z.getinfo(name)
            if info.file_size == 0 or info.file_size > MAX_BYTES:
                raise ValueError(f"Invalid video size: {name}")
            data = z.read(info)
            if data[4:8] != b"ftyp":
                raise ValueError(f"Not an MP4 container: {name}")
            extracted[name] = data
    # Validate all destinations before writing anything.
    for name, data in extracted.items():
        dest = ROOT / name
        if dest.exists() and hashlib.sha256(dest.read_bytes()).digest() != hashlib.sha256(data).digest():
            raise ValueError(f"Existing asset differs; refusing overwrite: {name}")
    pubspec = APP / "pubspec.yaml"
    original = pubspec.read_text()
    if "flutter:\n" not in original:
        raise ValueError("pubspec.yaml lacks a Flutter section")
    for name, data in extracted.items():
        dest = ROOT / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            dest.write_bytes(data)
        print(f"{name}: {len(data)} bytes sha256={hashlib.sha256(data).hexdigest()}")
    asset_line = "    - assets/gifts/"
    if asset_line not in original:
        if "  assets:\n" in original:
            updated = original.replace("  assets:\n", "  assets:\n" + asset_line + "\n", 1)
        else:
            updated = original.replace("flutter:\n", "flutter:\n  assets:\n" + asset_line + "\n", 1)
        pubspec.write_text(updated)
    print("Dragon videos registered. Verify codec, device playback and gift mapping before release.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: import_dragon_gifts.py ZIP_FILE")
    install(sys.argv[1])

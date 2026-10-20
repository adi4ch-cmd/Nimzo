#!/usr/bin/env python3
"""Export only media/UI assets from a user-supplied DangLive .apks archive.

Does not export base.apk, .dex, .so, compiled Flutter code, app signing files,
AndroidManifest.xml, or the original .apks container. Binary media is copied
unaltered. Use only with assets for which you have the appropriate rights.

Usage:
    python3 tools/extract_danglive_assets_only.py \
      "DangLive-1.1.17 (1).apks" \
      --output "DangLive_Extracted_Assets_Only.zip"
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import PurePosixPath
import sys
from zipfile import ZipFile, ZIP_DEFLATED, BadZipFile

MEDIA_EXTENSIONS = {
    ".svga", ".pag", ".mp4", ".mov", ".webm", ".gif", ".png",
    ".jpg", ".jpeg", ".webp", ".svg", ".apng", ".avif",
    ".mp3", ".m4a", ".wav", ".ogg", ".aac", ".flac",
    ".json", ".riv", ".lottie", ".ttf", ".otf",
}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".apng", ".avif"}
AUDIO_EXTENSIONS = {".mp3", ".m4a", ".wav", ".ogg", ".aac", ".flac"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".webm"}
ANIMATION_EXTENSIONS = {".svga", ".pag", ".lottie", ".riv"}


def category(ext: str) -> str:
    if ext in ANIMATION_EXTENSIONS:
        return "animations"
    if ext in VIDEO_EXTENSIONS:
        return "video"
    if ext in AUDIO_EXTENSIONS:
        return "audio"
    if ext in IMAGE_EXTENSIONS:
        return "images"
    if ext in (".ttf", ".otf"):
        return "fonts"
    return "data"


def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(name) and not name.startswith("/") and ".." not in path.parts and "\\" not in name


def is_real_asset(name: str) -> bool:
    if not safe_name(name):
        return False
    if not (
        name.startswith("assets/flutter_assets/assets/")
        or name.startswith("assets/flutter_assets/packages/")
        or name.startswith("res/drawable")
        or name.startswith("res/mipmap")
    ):
        return False
    return PurePosixPath(name).suffix.lower() in MEDIA_EXTENSIONS


def collect(apks_path: str, out_path: str) -> None:
    records = []
    seen = set()
    counts = {}
    with ZipFile(apks_path, "r") as outer, ZipFile(
        out_path, "w", compression=ZIP_DEFLATED, compresslevel=6,
        allowZip64=True,
    ) as bundle:
        apks = [x for x in outer.infolist() if x.filename.endswith(".apk") and not x.is_dir()]
        if not apks:
            raise ValueError("Input must contain at least one .apk")
        for apk_info in apks:
            with ZipFile(io.BytesIO(outer.read(apk_info)), "r") as apk:
                for item in apk.infolist():
                    if item.is_dir() or not is_real_asset(item.filename):
                        continue
                    # Keep the archive path to avoid collisions across split APKs.
                    archive_path = f"assets/{apk_info.filename}/{item.filename}"
                    if archive_path in seen:
                        continue
                    seen.add(archive_path)
                    data = apk.read(item)
                    ext = PurePosixPath(item.filename).suffix.lower()
                    kind = category(ext)
                    bundle.writestr(archive_path, data)
                    records.append({
                        "source_split": apk_info.filename,
                        "source_path": item.filename,
                        "zip_path": archive_path,
                        "category": kind,
                        "extension": ext,
                        "bytes": len(data),
                        "sha256": hashlib.sha256(data).hexdigest(),
                    })
                    counts[kind] = counts.get(kind, 0) + 1
        if not records:
            raise ValueError("No supported media assets found; check supplied archive.")
        headers = ["source_split", "source_path", "zip_path", "category", "extension", "bytes", "sha256"]
        with io.StringIO() as out:
            writer = csv.DictWriter(out, fieldnames=headers)
            writer.writeheader()
            writer.writerows(records)
            bundle.writestr("ASSET_MANIFEST.csv", out.getvalue())
        bundle.writestr("EXTRACTION_SUMMARY.json", json.dumps({
            "contents": "Original media and UI assets only; no source APK or app binaries",
            "total_files": len(records),
            "counts_by_category": counts,
            "svga_files": sum(x["extension"] == ".svga" for x in records),
            "pag_files": sum(x["extension"] == ".pag" for x in records),
            "note": "This package contains locally bundled resources only. Downloaded gift catalogs, server games, and Flutter/Dart source code are not included.",
        }, indent=2) + "\n")
        bundle.writestr("README_FOR_CODEX.txt",
            "DangLive asset-only export (for NIMZO review)\n"
            "Contains ORIGINAL bundled UI artwork, animations, videos, audio, fonts and JSON.\n"
            "No original APK, native libraries, compiled code or fake replacement designs.\n"
            "Assets retain their original paths under assets/<split-name>/.\n"
            "Use ASSET_MANIFEST.csv for file paths and SHA-256 checks.\n"
            "An APK cannot provide complete editable game source code, server config,\n"
            "or remote store/gift media not bundled in the supplied app.\n"
            "Before adding to NIMZO: verify format, review license, preview playback,\n"
            "map asset IDs to real store records, and test equip/rendering in rooms.\n")
    with ZipFile(out_path) as check:
        corrupt = check.testzip()
        if corrupt is not None:
            raise RuntimeError(f"Output ZIP integrity error: {corrupt}")
    print(json.dumps({
        "output": out_path,
        "total_media_files": len(records),
        "categories": counts,
        "svga": sum(x["extension"] == ".svga" for x in records),
        "pag": sum(x["extension"] == ".pag" for x in records),
        "original_APK_in_zip": False,
    }, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apks", help="Local source .apks file; never exported")
    parser.add_argument("--output", default="DangLive_Extracted_Assets_Only.zip")
    args = parser.parse_args()
    try:
        collect(args.apks, args.output)
    except (OSError, ValueError, BadZipFile, RuntimeError) as exc:
        sys.exit(f"Extraction failed: {exc}")

#!/usr/bin/env python3
"""Verified local import of user-provided WillChill media; run at NIMZO repo root."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import subprocess
import sys
import tempfile
import shutil
import zipfile

ROOT = Path.cwd()
PREFIX = "nimzo/assets/willchill_premium/"
REQUIRED_COUNT = 441

def stop(reason):
    sys.exit("WillChill import cancelled: " + reason)

def main():
    if not (ROOT / "nimzo/FEATURES.lock.json").is_file():
        stop("run in the NIMZO repository root")
    if len(sys.argv) != 2:
        stop("usage: python3 tools/import_willchill_package.py PATH_TO_ZIP")
    archive_path = Path(sys.argv[1])
    if not archive_path.is_file():
        stop("companion ZIP not found")
    destination = ROOT / PREFIX
    with zipfile.ZipFile(archive_path) as archive:
        members = [entry for entry in archive.infolist() if not entry.is_dir()]
        names = [entry.filename for entry in members]
        if len(names) != len(set(names)):
            stop("duplicate file paths inside ZIP")
        index = {entry.filename: entry for entry in members}
        catalog_path = PREFIX + "catalog.json"
        if catalog_path not in index:
            stop("catalog missing")
        catalog_bytes = archive.read(catalog_path)
        catalog = json.loads(catalog_bytes)
        records = catalog.get("records", [])
        if len(records) != REQUIRED_COUNT:
            stop("unexpected media record count")
        expected = set()
        levels = set()
        total = 0
        for record in records:
            asset = record["asset"]
            member = "nimzo/" + asset
            path = PurePosixPath(member)
            if (not asset.startswith("assets/willchill_premium/")
                or path.is_absolute() or ".." in path.parts
                or str(path) != member or member in expected or member not in index):
                stop("invalid media path: " + member)
            info = index[member]
            if info.file_size > 8_000_000 or info.file_size != record["bytes"]:
                stop("invalid size: " + member)
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                stop("symlink rejected: " + member)
            contents = archive.read(member)
            if hashlib.sha256(contents).hexdigest() != record["sha256"]:
                stop("hash mismatch: " + member)
            total += len(contents)
            expected.add(member)
            if record.get("group") == "svip" and isinstance(record.get("tier"), int):
                levels.add(record["tier"])
        if levels != set(range(1, 9)) or total > 100_000_000:
            stop("SVIP levels or size validation failed")
        if destination.exists():
            for record in records:
                file_path = ROOT / "nimzo" / record["asset"]
                if (not file_path.is_file()
                    or hashlib.sha256(file_path.read_bytes()).hexdigest() != record["sha256"]):
                    stop("existing media conflict, refusing to overwrite: " + str(file_path))
            if (destination / "catalog.json").read_bytes() != catalog_bytes:
                stop("existing catalog conflict")
            print("Media already installed and hashes verified")
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(dir=destination.parent) as temp:
                staged = Path(temp) / "willchill_premium"
                staged.mkdir()
                (staged / "catalog.json").write_bytes(catalog_bytes)
                for member in sorted(expected):
                    file_path = staged / member[len(PREFIX):]
                    file_path.parent.mkdir(parents=True, exist_ok=True)
                    file_path.write_bytes(archive.read(member))
                staged.rename(destination)
            print("Installed", len(expected), "verified media files")
    subprocess.run([sys.executable, "tools/verify_willchill_premium.py"], check=True)
    subprocess.run([sys.executable, "tools/install_willchill_premium.py"], check=True)
    print("Preview routes registered; test Flutter and device playback before publishing")
    print("Do not redistribute media without commercial permissions")

if __name__ == "__main__":
    main()

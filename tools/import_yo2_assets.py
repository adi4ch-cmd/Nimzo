#!/usr/bin/env python3
"""Import owner-approved Yo2 ZIP assets safely. Run: python3 tools/import_yo2_assets.py part1.zip part2.zip"""
import csv
import hashlib
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / "nimzo/assets/yo2_licensed"
PUBSPEC = ROOT / "nimzo/pubspec.yaml"
EXT = {".svga", ".mp4", ".webm", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".json"}

def main(archives):
    if len(archives) != 2 or not PUBSPEC.is_file():
        raise SystemExit("Expected two ZIP paths and nimzo/pubspec.yaml")
    files = {}
    total = 0
    for archive in archives:
        with zipfile.ZipFile(archive) as z:
            bad = z.testzip()
            if bad:
                raise ValueError(f"Corrupt ZIP entry: {bad}")
            for info in z.infolist():
                if info.is_dir():
                    continue
                path = pathlib.PurePosixPath(info.filename)
                if path.is_absolute() or ".." in path.parts or "\\" in info.filename:
                    raise ValueError(f"Unsafe path: {info.filename}")
                if path.suffix.lower() not in EXT:
                    continue
                total += info.file_size
                if info.file_size > 80_000_000 or total > 400_000_000:
                    raise ValueError("Unpacked asset size limit exceeded")
                data = z.read(info)
                digest = hashlib.sha256(data).hexdigest()
                if path in files and files[path][0] != digest:
                    raise ValueError(f"Conflicting asset: {path}")
                files[path] = (digest, data)
    for path, (digest, _) in files.items():
        target = DEST.joinpath(*path.parts)
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError(f"Refusing overwrite: {target}")
    spec = PUBSPEC.read_text()
    if "  assets:\n" not in spec:
        raise ValueError("Flutter assets section missing")
    for path, (_, data) in files.items():
        target = DEST.joinpath(*path.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            target.write_bytes(data)
    DEST.mkdir(parents=True, exist_ok=True)
    with (DEST / "ASSET_MANIFEST.csv").open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["flutter_path", "sha256", "bytes"])
        for path, (digest, data) in sorted(files.items()):
            writer.writerow([f"assets/yo2_licensed/{path}", digest, len(data)])
    # Flutter only bundles explicitly registered directories, not recursive children.
    dirs = sorted({str(path.parent) for path in files})
    missing = [f"    - assets/yo2_licensed/{d}/" for d in dirs
               if f"    - assets/yo2_licensed/{d}/" not in spec]
    if missing:
        PUBSPEC.write_text(spec.replace("  assets:\n",
                                        "  assets:\n" + "\n".join(missing) + "\n", 1))
    print(f"Imported {len(files)} assets in {len(dirs)} directories")
    print("Gift UUID and VIP entitlement mapping must be verified separately.")

if __name__ == "__main__":
    main(sys.argv[1:])

#!/usr/bin/env python3
"""Extract only media from the user-provided APKS; never install or execute it."""
import argparse
import collections
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import zipfile

MEDIA = {'.png', '.webp', '.jpg', '.jpeg', '.gif', '.svga', '.mp4', '.m4a', '.mp3'}


def extract(source, output, inventory_only=False):
    output.mkdir(parents=True, exist_ok=True)
    source_bytes = source.read_bytes()
    records = []
    total = 0
    with zipfile.ZipFile(io.BytesIO(source_bytes)) as bundle:
        with zipfile.ZipFile(io.BytesIO(bundle.read('base.apk'))) as apk:
            for entry in apk.infolist():
                path = PurePosixPath(entry.filename)
                if path.suffix.lower() not in MEDIA or entry.is_dir():
                    continue
                if path.is_absolute() or '..' in path.parts or '\\' in entry.filename:
                    raise ValueError('Unsafe media path')
                if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('Media symlinks are not allowed')
                total += entry.file_size
                if entry.file_size > 32 * 1024 * 1024 or total > 256 * 1024 * 1024:
                    raise ValueError('Unexpected media size')
                data = apk.read(entry)
                if not inventory_only:
                    destination = output.joinpath(*path.parts)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(data)
                records.append(dict(source_apk='base.apk', path=str(path),
                    bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    report = dict(apks_sha256=hashlib.sha256(source_bytes).hexdigest(),
        media_files=len(records), formats=dict(collections.Counter(
            PurePosixPath(row['path']).suffix for row in records)), files=records)
    (output / 'inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apks', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--inventory-only', action='store_true')
    args = parser.parse_args()
    result = extract(args.apks, args.output, args.inventory_only)
    print(json.dumps({key: value for key, value in result.items() if key != 'files'}))

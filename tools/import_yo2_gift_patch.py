#!/usr/bin/env python3
"""Import the SHA-pinned original Yo2 gift-only bundle; skip both Dragons."""
from __future__ import annotations
import csv
import hashlib
from io import StringIO
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'nimzo/assets/yo2_gifts/'
BUNDLE_SHA256 = 'e40912b9b651ee0ab5c62fdf848f33d542cca9f678a44c546a9bd65d95e1fc82'

def install(package: Path, *, dry_run: bool = False) -> int:
    if hashlib.sha256(package.read_bytes()).hexdigest() != BUNDLE_SHA256:
        raise ValueError('Unverified original Yo2 gift package SHA-256')
    with zipfile.ZipFile(package) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError('Corrupt original gift file: ' + bad)
        names = archive.namelist()
        if len(names) != 33 or len(set(names)) != 33:
            raise ValueError('Unexpected gift archive size')
        allowed = set(x for x in names if x.startswith(PREFIX))
        allowed.add('README_NON_DRAGON_GIFTS.txt')
        if set(names) != allowed:
            raise ValueError('Unexpected ZIP paths')
        images = [x for x in names if x.startswith(PREFIX + 'images/')
                  and x.endswith('.webp')]
        effects = [x for x in names if x.startswith(PREFIX + 'effects/')
                   and x.endswith('.svga')]
        if len(images) != 24 or len(effects) != 7:
            raise ValueError('Original Yo2 gift images / effects incomplete')
        entries = sorted(images + effects)
        if any('dragon' in x.lower() for x in entries):
            raise ValueError('Dragon is out of this gift integration')
        manifest = PREFIX + 'GIFT_ASSET_MANIFEST.csv'
        if manifest not in names:
            raise ValueError('Provenance manifest missing')
        rows = list(csv.DictReader(StringIO(archive.read(manifest).decode())))
        if len(rows) != 31:
            raise ValueError('Provenance manifest not complete')
        hashes = {
            PREFIX + row['nimzo_asset_path'].split('assets/yo2_gifts/', 1)[1]:
                row['sha256']
            for row in rows
        }
        for entry in entries:
            data = archive.read(entry)
            if hashlib.sha256(data).hexdigest() != hashes.get(entry):
                raise ValueError('Gift file mismatch: ' + entry)
            if entry in images and not (
                data[:4] == b'RIFF' and data[8:12] == b'WEBP'
            ):
                raise ValueError('Invalid original WebP: ' + entry)
            target = ROOT / entry
            if target.exists() and target.read_bytes() != data:
                raise ValueError('Refusing to overwrite changed gift: ' + entry)
        if dry_run:
            print('Verified 31 original Yo2 gift assets without writing files')
            return len(entries)
        for name in entries + [manifest]:
            target = ROOT / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                target.write_bytes(archive.read(name))
    pubspec = ROOT / 'nimzo/pubspec.yaml'
    contents = pubspec.read_text()
    marker = '  assets:\n'
    if marker not in contents:
        raise ValueError('Flutter assets registration missing')
    for group in ('images', 'effects'):
        entry = f'    - assets/yo2_gifts/{group}/\n'
        if entry not in contents:
            contents = contents.replace(marker, marker + entry, 1)
    pubspec.write_text(contents)
    print('Installed original Yo2 gift assets; both Dragons untouched')
    return len(entries)

if __name__ == '__main__':
    argv = [x for x in sys.argv[1:] if x != '--dry-run']
    if len(argv) != 1:
        raise SystemExit('Usage: import_yo2_gift_patch.py ZIP [--dry-run]')
    install(Path(argv[0]), dry_run='--dry-run' in sys.argv)

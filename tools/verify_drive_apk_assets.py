#!/usr/bin/env python3
"""Verify all four current imported manifests and originals in a real APK."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = {'drive_catalog': 9, 'drive_catalog_expanded': 48,
           'membership/remix': 70, 'drive_catalog_premium': 7}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    count = 0
    with ZipFile(args.apk) as apk:
        for folder, expected in FOLDERS.items():
            relative = f'assets/{folder}/manifest.json'
            data = (ROOT/'nimzo'/relative).read_bytes()
            assert apk.read('assets/flutter_assets/'+relative) == data, relative
            items = json.loads(data)['items']
            assert len(items) == expected, folder
            for row in items:
                for key in ['asset', 'thumbnail']:
                    if key not in row:
                        continue
                    path = row[key]
                    digest = row['sha256' if key == 'asset' else 'thumbnail_sha256']
                    size = row['bytes' if key == 'asset' else 'thumbnail_bytes']
                    raw = apk.read('assets/flutter_assets/'+path)
                    assert len(raw) == size and hashlib.sha256(raw).hexdigest() == digest, path
                count += 1
    assert count == 134
    print('PASS:134 exact imported products plus thumbnails and manifests compiled;13 requested gifts remain missing')


if __name__ == '__main__':
    main()

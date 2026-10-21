#!/usr/bin/env python3
"""Fail-closed APK media verifier. Run from the NIMZO repository root.

python3 tools/verify_willchill_apk_bundle.py nimzo/build/app/outputs/flutter-apk/app-release.apk

Verifies exact source assets by hash; does NOT claim device playback or media rights.
"""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

EXPECTED_COUNT = 261
PREFIX = 'assets/flutter_assets/'
MEDIA_PREFIX = 'assets/willchill_premium/'


def verify(apk_path: Path, catalog_path: Path) -> None:
    if not apk_path.is_file() or not catalog_path.is_file():
        raise ValueError('APK and installed media catalog must both exist')
    catalog_bytes = catalog_path.read_bytes()
    records = json.loads(catalog_bytes).get('records', [])
    if len(records) != EXPECTED_COUNT:
        raise ValueError(f'Expected {EXPECTED_COUNT} source assets, got {len(records)}')
    seen = set()
    verified_bytes = 0
    with zipfile.ZipFile(apk_path) as apk:
        members = set(apk.namelist())
        catalog_member = PREFIX + MEDIA_PREFIX + 'catalog.json'
        if catalog_member not in members or apk.read(catalog_member) != catalog_bytes:
            raise ValueError('APK premium catalog missing or differs from source')
        for item in records:
            asset = item['asset']
            if not asset.startswith(MEDIA_PREFIX) or '..' in Path(asset).parts:
                raise ValueError(f'Unsafe media path: {asset}')
            if asset in seen:
                raise ValueError(f'Duplicate media record: {asset}')
            seen.add(asset)
            member = PREFIX + asset
            if member not in members:
                raise ValueError(f'APK missing original media: {member}')
            content = apk.read(member)
            if len(content) != item['bytes']:
                raise ValueError(f'APK media size mismatch: {asset}')
            if hashlib.sha256(content).hexdigest() != item['sha256']:
                raise ValueError(f'APK media SHA256 mismatch: {asset}')
            if item['type'] == 'vap' and b'vapc' not in content:
                raise ValueError(f'Missing VAP alpha metadata: {asset}')
            verified_bytes += len(content)
        if PREFIX + 'AssetManifest.bin' not in members:
            raise ValueError('Flutter AssetManifest.bin missing')
    apk_hash = hashlib.sha256(apk_path.read_bytes()).hexdigest()
    print(f'PASS: all {len(seen)} media assets verified ({verified_bytes} bytes)')
    print(f'APK SHA256: {apk_hash}')
    print('Native Android playback and voice/audio coexistence still need device QA')


def main():
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python3 tools/verify_willchill_apk_bundle.py APK_PATH')
    try:
        verify(Path(sys.argv[1]), Path('nimzo/assets/willchill_premium/catalog.json'))
    except (KeyError, OSError, ValueError, zipfile.BadZipFile) as error:
        raise SystemExit(f'FAIL: premium APK is incomplete: {error}') from error


if __name__ == '__main__':
    main()

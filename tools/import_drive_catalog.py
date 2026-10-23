#!/usr/bin/env python3
"""Reproducibly extract selected self-contained SVGA from owner-supplied APKs.
Does not activate products or modify wallets. Android proof is a separate step.
"""
import hashlib
import io
import json
from pathlib import Path
import sys
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SELECTION = [
    ('WithU-1.6.5.apks', 'assets/withu/gift_rain.svga', 'gift', 'Gift Shower', 7500),
    ('YoHo-5.48.40.apks', 'assets/aladdin.svga', 'gift', 'Magic Genie', 15000),
    *[('BGChat-3.0.6.apks', f'assets/header_wear_{n}.svga', 'Avatar Frame', name, 10000)
      for n, name in enumerate(['Amethyst Crown', 'Azure Crown', 'Orchid Crown', 'Crimson Crown'], 1)],
    *[('BazmiVoiceChat-1.0.8.apks', f'assets/flutter_assets/assets/animations/id_plates/{tier}.svga',
       'ID Frame', name, 5000) for tier, name in [('common', 'Rose ID Plate'), ('rare', 'Violet ID Plate'), ('epic', 'Gold ID Plate')]],
]

def main(package_dir, audit_file):
    audit = {p['filename']: p for p in json.loads(Path(audit_file).read_text())['packages']}
    dest = ROOT / 'nimzo/assets/drive_catalog'
    dest.mkdir(parents=True, exist_ok=True)
    items = []
    for package, source, category, name, price in SELECTION:
        package_bytes = (Path(package_dir) / package).read_bytes()
        package_hash = hashlib.sha256(package_bytes).hexdigest()
        if package_hash != audit[package]['sha256']:
            raise ValueError(f'Package hash changed: {package}')
        with zipfile.ZipFile(io.BytesIO(package_bytes)) as outer:
            with zipfile.ZipFile(io.BytesIO(outer.read('base.apk'))) as inner:
                data = inner.read(source)
        sha = hashlib.sha256(data).hexdigest()
        slug = name.lower().replace(' ', '-')
        product_id = (str(uuid.uuid5(uuid.NAMESPACE_URL, 'nimzo:drive:20261022:' + slug))
                      if category == 'gift' else 'nimzo-drive-' + slug)
        asset = f'assets/drive_catalog/{sha}.svga'
        target = ROOT / 'nimzo' / asset
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f'Refusing replacement: {target}')
        target.write_bytes(data)
        items.append(dict(id=product_id, name=name, category=category, coin_price=price,
                          asset=asset, sha256=sha, bytes=len(data), media_kind='svga',
                          source_package=package, source_package_sha256=package_hash,
                          source=f'base.apk!/{source}', drive_id=audit[package]['drive_id']))
    (dest / 'manifest.json').write_text(json.dumps(dict(
        schema=1, authorization='Owner requested extraction and activation of supplied Drive APK gifts and Store items, 2026-10-22',
        device_verification='Separate Android emulator render evidence required before activation', items=items), indent=2)+'\n')
    print(f'Extracted {len(items)} original animations; no backend changes.')

if __name__ == '__main__':
    main(*sys.argv[1:])

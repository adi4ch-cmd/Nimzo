#!/usr/bin/env python3
"""Verify a Store test APK against the checked-out, pinned media manifest."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path('assets/premium_store/manifest.json')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_archive(apk, project=ROOT / 'nimzo'):
    manifest_bytes = (project / MANIFEST).read_bytes()
    manifest = json.loads(manifest_bytes)
    assert len(manifest) == 32, 'Expected exactly 32 Store products'
    assert len({item['id'] for item in manifest}) == 32, 'Duplicate product IDs'
    assert len({item['category'] for item in manifest}) == 9, 'Expected nine categories'
    thumbnails = {item['thumbnail'] for item in manifest if item.get('thumbnail')}
    assert len(thumbnails) == 5, 'Expected five entrance thumbnails'
    checks = []
    with ZipFile(apk) as package:
        names = package.namelist()
        assert package.testzip() is None, 'Corrupt APK ZIP'

        def bundled(path):
            assert path.startswith('assets/premium_store/'), 'Unexpected media path'
            assert '..' not in Path(path).parts, 'Unsafe media path'
            entry = 'assets/flutter_assets/' + path
            assert names.count(entry) == 1, f'Missing or duplicate media: {path}'
            return package.read(entry)

        assert bundled(MANIFEST.as_posix()) == manifest_bytes, 'Packaged manifest differs from source'
        for item in manifest:
            payload = bundled(item['asset'])
            expected = item['sha256']
            assert re.fullmatch(r'[0-9a-f]{64}', expected), 'Invalid manifest digest'
            assert digest(payload) == expected, f"Media SHA mismatch: {item['id']}"
            checks.append({'id': item['id'], 'asset': item['asset'], 'sha256': expected})
        for path in sorted(thumbnails):
            payload = bundled(path)
            expected = digest((project / path).read_bytes())
            assert digest(payload) == expected, f'Thumbnail SHA mismatch: {path}'
            checks.append({'thumbnail': path, 'sha256': expected})

        libraries = [name for name in names if name.startswith('lib/') and name.endswith('.so')]
        assert libraries, 'APK has no native libraries'
        assert any(name.startswith('lib/x86_64/') for name in libraries), 'Android emulator ABI missing'
        assert not any('vivox' in name.lower() for name in names), 'Native Vivox library packaged'
        with tempfile.TemporaryDirectory(prefix='nimzo-apk-elf-') as folder:
            library = Path(folder) / 'library.so'
            for name in libraries:
                library.write_bytes(package.read(name))
                dynamic = subprocess.check_output(
                    ['readelf', '--dynamic', '--wide', str(library)], text=True)
                dependencies = [line for line in dynamic.splitlines() if '(NEEDED)' in line]
                assert not any('vivox' in line.lower() for line in dependencies), f'Vivox SDK linked by {name}'
    return {'products': 32, 'categories': 9, 'thumbnails': 5,
            'vivox_sdk_linked': False, 'verified_assets': checks}


def verify_android(apk):
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    assert sdk, 'Android SDK must be available for package/signature verification'
    candidates = list(Path(sdk).glob('build-tools/*/aapt'))
    assert candidates, 'Android build-tools aapt missing'
    tools = max(candidates, key=lambda path: tuple(int(n) for n in re.findall(r'\d+', path.parent.name))).parent
    badging = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(apk)], text=True)
    for expected in ("package: name='io.nimzo.app'", "versionCode='137'", "versionName='1.0.37'"):
        assert expected in badging, f'Wrong APK identity/version: {expected}'
    subprocess.run([str(tools / 'apksigner'), 'verify', '--verbose', str(apk)], check=True)
    subprocess.run([str(tools / 'zipalign'), '-c', '-P', '16', '4', str(apk)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--report', type=Path, default=Path('nimzo/build/premium-store-apk-report.json'))
    args = parser.parse_args()
    report = verify_archive(args.apk)
    verify_android(args.apk)
    report.update(apk_sha256=digest(args.apk.read_bytes()), version='1.0.37+137')
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: 32 Store media SHA256, five thumbnails, package/signature/alignment, no linked Vivox SDK')


if __name__ == '__main__':
    main()

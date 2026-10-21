"""Contract tests for fail-closed WillChill APK asset verifier.

Only synthetic fixtures. No third-party media distributed by these tests.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().with_name('verify_willchill_apk_bundle.py')
spec = importlib.util.spec_from_file_location('premium_verify', SCRIPT)
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class PremiumAPKIntegrity(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.catalog = self.root / 'catalog.json'
        self.apk = self.root / 'test.apk'
        self.records = []
        self.payloads = {}
        for n in range(check.EXPECTED_COUNT):
            asset = f'assets/willchill_premium/gifts/fixture_{n:03}.png'
            data = f'synthetic-media-fixture-{n}'.encode('ascii')
            self.payloads[asset] = data
            self.records.append({
                'asset': asset, 'bytes': len(data),
                'sha256': hashlib.sha256(data).hexdigest(),
                'type': 'image',
            })
        self.catalog.write_text(json.dumps({'records': self.records}))

    def make_apk(self, *, missing=False, corrupt=False, no_catalog=False):
        with zipfile.ZipFile(self.apk, 'w') as apk:
            apk.writestr('assets/flutter_assets/AssetManifest.bin', b'fixture')
            if not no_catalog:
                apk.write(self.catalog,
                    'assets/flutter_assets/assets/willchill_premium/catalog.json')
            for idx, (name, data) in enumerate(self.payloads.items()):
                if missing and idx == check.EXPECTED_COUNT - 1:
                    continue
                if corrupt and idx == 50:
                    data = b'wrong-content'
                apk.writestr('assets/flutter_assets/' + name, data)

    def test_all_restored_premium_media_pass(self):
        self.make_apk()
        check.verify(self.apk, self.catalog)

    def test_missing_media_fails(self):
        self.make_apk(missing=True)
        with self.assertRaisesRegex(ValueError, 'missing'):
            check.verify(self.apk, self.catalog)

    def test_tampered_media_fails(self):
        self.make_apk(corrupt=True)
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            check.verify(self.apk, self.catalog)

    def test_missing_catalog_fails(self):
        self.make_apk(no_catalog=True)
        with self.assertRaisesRegex(ValueError, 'catalog'):
            check.verify(self.apk, self.catalog)


if __name__ == '__main__':
    unittest.main()

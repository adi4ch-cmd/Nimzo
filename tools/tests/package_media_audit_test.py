import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('audit', Path(__file__).parents[1] / 'audit_app_media.py')


class PackageAuditTest(unittest.TestCase):
    def test_nested_packages_classify_and_hash_media_without_exporting_private_files(self):
        module = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(module)
        apk = io.BytesIO()
        with zipfile.ZipFile(apk, 'w') as archive:
            archive.writestr('assets/gift/rose.svga', b'approved-animation')
            archive.writestr('assets/frame/rose.svga', b'approved-animation')
            archive.writestr('assets/credentials.json', b'private-content')
            archive.writestr('assets/token.png', b'private-content')
            archive.writestr('res/layout/room.xml', b'binary-layout')
            archive.writestr('../assets/unsafe.png', b'unsafe')
            archive.writestr('classes.dex', b'executable')
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'sample.apks'
            with zipfile.ZipFile(source, 'w') as archive:
                archive.writestr('base.apk', apk.getvalue())
            result = module.audit_package(source)
        self.assertEqual(result['status'], 'AUDITED')
        media = result['media']
        self.assertEqual(len(media), 3)
        self.assertEqual(media[0]['sha256'], media[1]['sha256'])
        self.assertEqual(media[0]['format'], 'svga')
        self.assertEqual(media[0]['compatibility'], 'flutter_svga; runtime decode required')
        self.assertEqual(media[0]['rights'], 'owner permission asserted; per-asset scope unverified')
        self.assertTrue(all('private-content' not in str(entry) for entry in media))

    def test_corrupt_package_is_blocked_without_losing_other_results(self):
        module = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'broken.apks'
            source.write_bytes(b'not-a-zip')
            result = module.audit_package(source)
        self.assertEqual(result['status'], 'BLOCKED')
        self.assertEqual(result['media'], [])


if __name__ == '__main__':
    unittest.main()

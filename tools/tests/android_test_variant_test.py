import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AndroidTestVariantTest(unittest.TestCase):
    def test_side_by_side_package_keeps_native_namespace_and_unique_provider(self):
        spec = importlib.util.spec_from_file_location('test_variant', ROOT / 'tools/configure_android_test_variant.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gradle = root / 'app/build.gradle.kts'
            gradle.parent.mkdir(parents=True)
            gradle.write_text('android { namespace = "io.nimzo.app"\n defaultConfig { applicationId = "io.nimzo.app" } }\n')
            manifest = root / 'app/src/main/AndroidManifest.xml'
            manifest.parent.mkdir(parents=True)
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Nimzo"><activity android:name=".MainActivity"/><provider android:authorities="io.nimzo.app.apk_updates"/></application></manifest>')
            module.configure(root)
            self.assertIn('namespace = "io.nimzo.app"', gradle.read_text())
            self.assertIn('applicationId = "io.nimzo.app.test"', gradle.read_text())
            self.assertIn('useLegacyPackaging = true', gradle.read_text())
            self.assertIn('android:authorities="${applicationId}.apk_updates"', manifest.read_text())
            self.assertIn('android:name="io.nimzo.app.MainActivity"', manifest.read_text())
            self.assertIn('android:label="Nimzo Test"', manifest.read_text())
            before = gradle.read_text(), manifest.read_text()
            module.configure(root)
            self.assertEqual(before, (gradle.read_text(), manifest.read_text()))

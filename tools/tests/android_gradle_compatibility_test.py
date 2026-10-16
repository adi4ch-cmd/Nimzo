import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AndroidGradleCompatibilityTest(unittest.TestCase):
    def test_generated_agp9_project_uses_kotlin_compatible_api36_toolchain(self):
        spec = importlib.util.spec_from_file_location('android_gradle', ROOT / 'tools/configure_android_gradle.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            wrapper = root / 'gradle/wrapper/gradle-wrapper.properties'
            wrapper.parent.mkdir(parents=True)
            wrapper.write_text('distributionUrl=https\\://services.gradle.org/distributions/gradle-9.3.1-all.zip\n')
            settings = root / 'settings.gradle.kts'
            settings.write_text('plugins {\n id("com.android.application") version "9.1.0" apply false\n id("org.jetbrains.kotlin.android") version "2.4.0" apply false\n}\n')
            module.configure(root)
            self.assertIn('version "8.11.1"', settings.read_text())
            self.assertIn('version "2.2.0"', settings.read_text())
            self.assertIn('gradle-8.14.3-all.zip', wrapper.read_text())
            before = (settings.read_text(), wrapper.read_text())
            module.configure(root)
            self.assertEqual(before, (settings.read_text(), wrapper.read_text()))

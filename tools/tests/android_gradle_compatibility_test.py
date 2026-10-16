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
            self.assertIn('version "2.2.20"', settings.read_text())
            self.assertIn('gradle-8.14.3-all.zip', wrapper.read_text())
            before = (settings.read_text(), wrapper.read_text())
            module.configure(root)
            self.assertEqual(before, (settings.read_text(), wrapper.read_text()))

    def test_current_flutter_template_applies_external_kotlin_before_flutter(self):
        spec = importlib.util.spec_from_file_location('android_gradle', ROOT / 'tools/configure_android_gradle.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            wrapper = root / 'gradle/wrapper/gradle-wrapper.properties'
            wrapper.parent.mkdir(parents=True)
            wrapper.write_text('distributionUrl=https\\://services.gradle.org/distributions/gradle-9.3.1-all.zip\n')
            (root / 'settings.gradle.kts').write_text('plugins {\n id("com.android.application") version "9.1.0" apply false\n id("org.jetbrains.kotlin.android") version "2.4.0" apply false\n}\n')
            app = root / 'app/build.gradle.kts'
            app.parent.mkdir()
            app.write_text('plugins {\n id("com.android.application")\n id("dev.flutter.flutter-gradle-plugin")\n}\n')
            properties = root / 'gradle.properties'
            properties.write_text('org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G\nandroid.useAndroidX=true\n')
            module.configure(root)
            value = app.read_text()
            self.assertIn('id("org.jetbrains.kotlin.android")', value)
            self.assertLess(value.index('id("org.jetbrains.kotlin.android")'), value.index('id("dev.flutter.flutter-gradle-plugin")'))
            self.assertIn('org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G', properties.read_text())
            self.assertIn('org.gradle.workers.max=2', properties.read_text())
            before_properties = properties.read_text()
            module.configure(root)
            self.assertEqual(value, app.read_text())
            self.assertEqual(before_properties, properties.read_text())

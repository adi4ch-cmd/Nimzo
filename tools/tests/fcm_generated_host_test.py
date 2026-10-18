import importlib.util,json,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class FcmGeneratedHostTest(unittest.TestCase):
 def test_generated_host_retains_voice_and_configures_notification_runtime(self):
  spec=importlib.util.spec_from_file_location('host',ROOT/'nimzo/tool/configure_fcm_android.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);android=root/'android';app=android/'app/build.gradle.kts';app.parent.mkdir(parents=True)
   (android/'settings.gradle.kts').write_text('plugins {\n id("com.android.application") version "8.11.1" apply false\n}\n')
   app.write_text('plugins {\n id("com.android.application")\n}\nandroid { namespace = "io.nimzo.nimzo"\n defaultConfig { applicationId = "io.nimzo.nimzo" }\n}\n// Vivox must survive\n')
   main=android/'app/src/main/kotlin/io/nimzo/nimzo/MainActivity.kt';main.parent.mkdir(parents=True);main.write_text('package io.nimzo.nimzo\nclass MainActivity\n')
   manifest=android/'app/src/main/AndroidManifest.xml';manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application /></manifest>')
   data=(ROOT/'nimzo/tool/firebase_android_client.json').read_text();module.run(root,data)
   self.assertIn('isCoreLibraryDesugaringEnabled = true',app.read_text())
   self.assertIn('desugar_jdk_libs:2.1.4',app.read_text());self.assertIn('Vivox must survive',app.read_text())
   self.assertIn('com.google.firebase.messaging.default_notification_channel_id',manifest.read_text());self.assertIn('nimzo_activity',manifest.read_text())
   self.assertTrue((android/'app/src/main/res/drawable/nimzo_notification_icon.xml').exists())
   before=app.read_text();module.run(root,data);self.assertEqual(before,app.read_text())

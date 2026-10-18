import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
class FirebaseAndroidTest(unittest.TestCase):
 def test_configures_android_resources_and_permission_without_billing_products(self):
  spec=importlib.util.spec_from_file_location('firebase',ROOT/'tools/configure_android_firebase.py')
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);manifest=root/'app/src/main/AndroidManifest.xml';manifest.parent.mkdir(parents=True)
   manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application /></manifest>')
   config=root/'google-services.json';config.write_text(json.dumps({'project_info':{'project_number':'123','project_id':'nimzo-test'},'client':[{'client_info':{'mobilesdk_app_id':'1:123:android:abc','android_client_info':{'package_name':'io.nimzo.app'}},'api_key':[{'current_key':'public-test-key'}]}]}))
   module.configure(root,config)
   resources=(root/'app/src/main/res/values/nimzo_firebase.xml').read_text()
   self.assertIn('google_app_id',resources);self.assertIn('1:123:android:abc',resources)
   self.assertIn('android.permission.POST_NOTIFICATIONS',manifest.read_text())
   self.assertIn('firebase_analytics_collection_deactivated',manifest.read_text())
   before=manifest.read_text();module.configure(root,config);self.assertEqual(before,manifest.read_text())
 def test_wrong_android_package_is_rejected(self):
  spec=importlib.util.spec_from_file_location('firebase',ROOT/'tools/configure_android_firebase.py')
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);config=root/'google-services.json';config.write_text(json.dumps({'project_info':{},'client':[]}))
   with self.assertRaises(ValueError):module.configure(root,config)

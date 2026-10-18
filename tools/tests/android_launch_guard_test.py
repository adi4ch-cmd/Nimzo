import importlib.util
import pathlib
import unittest
p=pathlib.Path('tools/verify_android_launch.py')
s=importlib.util.spec_from_file_location('launch',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class LaunchGuard(unittest.TestCase):
 def test_live_process_with_dart_startup_exception_fails(self):
  with self.assertRaisesRegex(RuntimeError,'startup'):
   m.verify_startup_log('[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: PlatformException(java.lang.NoSuchMethodError)')
 def test_clean_flutter_startup_passes(self):
  m.verify_startup_log('I FirebaseInitProvider: FirebaseApp initialization successful\nI flutter: Started')

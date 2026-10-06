"""Source contract checks for platform code requiring the external Vivox SDK."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
class NativeVoiceContract(unittest.TestCase):
    def test_response_handles_are_copied_before_message_destroy(self):
        source = (ROOT / 'native/vivox/android/vivox_bridge.cpp').read_text()
        for response in ('resp->connector_handle', 'lr->account_handle', 'join_resp->session_handle'):
            self.assertIn('vx_strdup(' + response + ')', source)
    def test_jni_requests_run_on_serial_worker(self):
        source = (ROOT / 'native/vivox/android/MainActivity.java').read_text()
        self.assertIn('newSingleThreadExecutor', source)
        self.assertIn('RECORD_AUDIO', source)
        self.assertIn('"status", status', source)
if __name__ == '__main__':
    unittest.main()

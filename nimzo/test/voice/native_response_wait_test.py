"""Execute the production native queue-wait function with a host SDK queue fixture."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


class NativeResponseWait(unittest.TestCase):
    def test_response_error_stages_are_stable_and_safe(self):
        compiler = shutil.which('g++') or shutil.which('clang++')
        if not compiler:
            self.skipTest('Host C++ compiler unavailable')
        source = (Path(__file__).resolve().parents[2] /
                  'native/vivox/android/vivox_bridge.cpp').read_text()
        function = re.search(r'static const char\* response_stage\([\s\S]*?\n}\n', source).group()
        cases = {
            'resp_connector_create': 'connector',
            'resp_account_anonymous_login': 'login',
            'resp_sessiongroup_add_session': 'channel-join',
            'resp_connector_mute_local_mic': 'microphone',
            'resp_connector_mute_local_speaker': 'speaker',
            'resp_sessiongroup_remove_session': 'leave',
            'resp_account_logout': 'leave',
        }
        harness = '#include <cassert>\n#include <cstring>\n'
        harness += 'enum vx_response_type {' + ','.join(cases) + ', unknown};\n'
        harness += function + 'int main() {\n'
        for response, stage in cases.items():
            harness += f'assert(strcmp(response_stage({response}), "{stage}") == 0);\n'
        harness += 'assert(strcmp(response_stage(unknown), "native") == 0); }\n'
        with tempfile.TemporaryDirectory(prefix='nimzo-native-stage-') as temporary:
            cpp = Path(temporary) / 'stage.cpp'
            binary = Path(temporary) / 'stage-test'
            cpp.write_text(harness)
            subprocess.run([compiler, '-std=c++17', str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)

    def test_queued_events_do_not_consume_a_fictitious_timeout(self):
        compiler = shutil.which('g++') or shutil.which('clang++')
        if not compiler:
            self.skipTest('Host C++ compiler unavailable')
        source = (Path(__file__).resolve().parents[2] /
                  'native/vivox/android/vivox_bridge.cpp').read_text()
        function = re.search(r'static int wait_for_response\([\s\S]*?\n}\n', source).group()
        harness = r'''
#include <chrono>
#include <algorithm>
#include <thread>
#include <vector>
#include <cassert>
using vx_response_type = int;
constexpr int msg_response = 1;
struct vx_message_base_t { int type; };
struct vx_resp_base_t { vx_message_base_t message; int type; };
static std::vector<vx_message_base_t*> queue;
static int dispatched = 0, destroyed = 0;
static vx_message_base_t* vx_wait_for_message(int ms) {
  if (queue.empty()) { std::this_thread::sleep_for(std::chrono::milliseconds(ms)); return nullptr; }
  auto* result = queue.front(); queue.erase(queue.begin()); return result;
}
static void handle_message(vx_message_base_t*) { ++dispatched; }
static void vx_destroy_message(vx_message_base_t*) { ++destroyed; }
'''
        harness += function + r'''
int main() {
  vx_message_base_t events[200];
  for (auto& event : events) { event.type = 2; queue.push_back(&event); }
  vx_resp_base_t reply{{msg_response}, 42}; queue.push_back(&reply.message);
  vx_message_base_t* out = nullptr;
  // All 200 events are immediately available: they must not count as 20 seconds.
  assert(wait_for_response(42, 1000, &out) == 0);
  assert(out == &reply.message && dispatched == 200 && destroyed == 200);
  auto start = std::chrono::steady_clock::now();
  assert(wait_for_response(42, 10, &out) == -1);
  auto elapsed = std::chrono::steady_clock::now() - start;
  assert(elapsed >= std::chrono::milliseconds(10));
  assert(elapsed < std::chrono::milliseconds(100));
}
'''
        with tempfile.TemporaryDirectory(prefix='nimzo-native-wait-') as temporary:
            cpp = Path(temporary) / 'wait.cpp'
            binary = Path(temporary) / 'wait-test'
            cpp.write_text(harness)
            subprocess.run([compiler, '-std=c++17', '-pthread', str(cpp), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == '__main__':
    unittest.main()

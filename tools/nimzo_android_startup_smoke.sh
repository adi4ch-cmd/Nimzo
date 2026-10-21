#!/usr/bin/env bash
set -euo pipefail
apk=nimzo/build/app/outputs/flutter-apk/app-release.apk
adb install -r "$apk"
adb logcat -c
adb shell am start -W -n io.nimzo.app/io.nimzo.app.MainActivity
# Startup initializes Supabase for up to 12 seconds; do not
# mistake a fast process start for a rendered Flutter screen.
sleep 23
pid="$(adb shell pidof io.nimzo.app | tr -d '\\r')"
test -n "$pid" || { adb logcat -d -v brief | tail -200; exit 1; }
mkdir -p nimzo/build/startup-evidence
adb exec-out screencap -p > nimzo/build/startup-evidence/launch.png
adb logcat -d -v time > nimzo/build/startup-evidence/logcat.txt
python3 -m pip install --quiet pillow
python3 - <<'PY'
from PIL import Image, ImageStat
p='nimzo/build/startup-evidence/launch.png'
img=Image.open(p).convert('RGB')
st=ImageStat.Stat(img)
assert img.width>=320 and img.height>=640, 'Invalid screenshot'
# Not a proof of login, but fails if the emulator only shows
# a uniform black native splash after the startup timeout.
assert max(st.stddev)>12, 'Blank/uniform startup screen'
print('Android startup nonblank frame: PASS', img.size, st.stddev)
PY
# A responsive error screen is NOT a passed login/startup test.
if grep -Fq 'NIMZO startup failed' nimzo/build/startup-evidence/logcat.txt; then
  echo 'Flutter initialization failed despite drawing a frame'
  exit 1
fi
adb shell uiautomator dump /sdcard/nimzo_window.xml >/dev/null 2>&1 || true
adb shell cat /sdcard/nimzo_window.xml > nimzo/build/startup-evidence/window.xml 2>/dev/null || true
if grep -Eiq 'could not start|initialization error|Android startup error|tap retry' nimzo/build/startup-evidence/window.xml; then
  echo 'App is stuck on startup Retry/error screen'
  exit 1
fi
if grep -E 'FATAL EXCEPTION:|Fatal signal [0-9]+' nimzo/build/startup-evidence/logcat.txt | grep -E -i -q 'nimzo|flutter|vivox'; then
  echo 'Potential Android crash found in launch log'; exit 1
fi

#!/usr/bin/env bash
set -euo pipefail
adb wait-for-device
adb shell getprop ro.build.version.release > diagnostics/android-version.txt
adb shell getconf PAGE_SIZE > diagnostics/page-size.txt
adb install -r -g released/old/*.apk > diagnostics/install-old.txt 2>&1
set +e
adb install -r -g released/current/*.apk > diagnostics/upgrade.txt 2>&1
upgrade_status=$?
set -e
printf '%s\n' "$upgrade_status" > diagnostics/upgrade-exit.txt
adb logcat -d > diagnostics/upgrade-logcat.txt
# Data removal is limited to this disposable emulator, never an owner device.
adb uninstall io.nimzo.app > diagnostics/emulator-reset.txt
adb logcat -c
adb install -r -g released/current/*.apk > diagnostics/install-current.txt 2>&1
adb shell monkey -p io.nimzo.app -c android.intent.category.LAUNCHER 1 > diagnostics/start.txt
sleep 20
adb shell pidof io.nimzo.app > diagnostics/process.txt
adb logcat -d > diagnostics/current-logcat.txt
adb exec-out screencap -p > diagnostics/current.png
cat diagnostics/upgrade.txt diagnostics/install-current.txt diagnostics/process.txt

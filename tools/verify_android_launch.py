#!/usr/bin/env python3
"""Install the built APK and verify that its Android process stays alive.

This is an unauthenticated launch smoke test, not a device voice-call test.
"""
import argparse
from pathlib import Path
import subprocess
import time


def adb(*args, **kwargs):
    return subprocess.run(['adb', *args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--package', choices=('io.nimzo.app', 'io.nimzo.app.test'), default='io.nimzo.app')
    parser.add_argument('--coexist-with', type=Path)
    args = parser.parse_args()
    if not args.apk.is_file():
        raise SystemExit(f'APK missing: {args.apk}')
    output = Path('android-launch-diagnostics')
    output.mkdir(exist_ok=True)
    adb('wait-for-device')
    if args.coexist_with:
        if args.package != 'io.nimzo.app.test' or not args.coexist_with.is_file():
            raise SystemExit('Coexistence test requires the separate test package and a baseline APK')
        adb('install', '-r', '-g', str(args.coexist_with))
        packages = adb('shell', 'cmd', 'package', 'list', 'packages', '-U', 'io.nimzo.app', capture_output=True, text=True).stdout.splitlines()
        previous_uid = next((line for line in packages if line.startswith('package:io.nimzo.app ')), None)
        if previous_uid is None:
            raise SystemExit('Existing Nimzo package not found after baseline installation')
    adb('install', '-r', '-g', str(args.apk))
    if args.coexist_with:
        after = adb('shell', 'cmd', 'package', 'list', 'packages', '-U', 'io.nimzo.app', capture_output=True, text=True).stdout.splitlines()
        if previous_uid not in after:
            raise SystemExit('Existing Nimzo package/UID changed during test installation')
        adb('shell', 'pm', 'path', 'io.nimzo.app')
        print('PASS: existing Nimzo package and UID preserved beside Nimzo Test')
    adb('logcat', '-c')
    adb('shell', 'monkey', '-p', args.package, '-c',
        'android.intent.category.LAUNCHER', '1')
    time.sleep(20)
    # Capture diagnostics before checking the process, including on startup crash.
    with (output / 'launch-logcat.txt').open('w') as log:
        adb('logcat', '-d', stdout=log, text=True)
    with (output / 'launch.png').open('wb') as screenshot:
        adb('exec-out', 'screencap', '-p', stdout=screenshot)
    process = adb('shell', 'pidof', args.package, capture_output=True, text=True)
    if not process.stdout.strip():
        raise SystemExit('NIMZO has no running process after Android launch')
    crash = adb('logcat', '-b', 'crash', '-d', capture_output=True, text=True).stdout
    (output / 'crash-logcat.txt').write_text(crash)
    if 'Process: ' + args.package in crash:
        raise SystemExit('NIMZO crashed after installation; see launch diagnostics')
    (output / 'result.txt').write_text(
        'PASS: APK installed and remained running for 20 seconds on Android.\n'
        'No authenticated voice, purchase, or physical-device validation implied.\n'
    )
    print('Android emulator APK installation and launch: PASS')


if __name__ == '__main__':
    main()

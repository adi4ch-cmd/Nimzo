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


def verify_startup_log(log):
    # A Dart isolate can fail before runApp while the Android process stays alive.
    if 'Unhandled Exception:' in log or 'FATAL EXCEPTION:' in log:
        raise RuntimeError('NIMZO startup exception; see launch diagnostics')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    if not args.apk.is_file():
        raise SystemExit(f'APK missing: {args.apk}')
    output = Path('android-launch-diagnostics')
    output.mkdir(exist_ok=True)
    adb('wait-for-device')
    adb('install', '-r', '-g', str(args.apk))
    adb('logcat', '-c')
    adb('shell', 'monkey', '-p', 'io.nimzo.app', '-c',
        'android.intent.category.LAUNCHER', '1')
    time.sleep(20)
    # Capture diagnostics before checking the process, including on startup crash.
    with (output / 'launch-logcat.txt').open('w') as log:
        adb('logcat', '-d', stdout=log, text=True)
    with (output / 'launch.png').open('wb') as screenshot:
        adb('exec-out', 'screencap', '-p', stdout=screenshot)
    verify_startup_log((output / 'launch-logcat.txt').read_text())
    process = adb('shell', 'pidof', 'io.nimzo.app', capture_output=True, text=True)
    if not process.stdout.strip():
        raise SystemExit('NIMZO has no running process after Android launch')
    crash = adb('logcat', '-b', 'crash', '-d', capture_output=True, text=True).stdout
    (output / 'crash-logcat.txt').write_text(crash)
    if 'Process: io.nimzo.app' in crash:
        raise SystemExit('NIMZO crashed after installation; see launch diagnostics')
    (output / 'result.txt').write_text(
        'PASS: APK installed and remained running for 20 seconds without unhandled startup exceptions.\n'
        'No authenticated voice, purchase, or physical-device validation implied.\n'
    )
    print('Android emulator APK installation and launch: PASS')


if __name__ == '__main__':
    main()

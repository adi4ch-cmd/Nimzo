"""Verify development-signed APK artifacts without accepting them as updater releases."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile


def verify(apk):
    tools = sorted(Path(os.environ['ANDROID_HOME']).glob('build-tools/*/apksigner'))[-1].parent
    signature = subprocess.check_output(
        [str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk)], text=True)
    certificates = {v.replace(':', '').lower() for v in re.findall(
        r'certificate SHA-256 digest:\s*([0-9a-fA-F:]+)', signature)}
    root = Path(__file__).resolve().parents[1]
    permanent = (root / 'nimzo/native/vivox/android/release-signing-certificate.sha256').read_text().strip()
    assert len(certificates) == 1 and permanent not in certificates, 'Test signing must differ from permanent signing'
    version, build = re.search(r'^version:\s*([^+\n]+)\+(\d+)',
                              (root / 'nimzo/pubspec.yaml').read_text(), re.M).groups()
    badging = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(apk)], text=True)
    for expected in ("package: name='io.nimzo.app'", f"versionCode='{build}'", f"versionName='{version}'",
                     'android.permission.INTERNET', 'android.permission.RECORD_AUDIO'):
        assert expected in badging, f'Missing package/version/permission: {expected}'
    manifest = subprocess.check_output([str(tools / 'aapt'), 'dump', 'xmltree', str(apk), 'AndroidManifest.xml'], text=True)
    for expected in ('login-callback', 'io.nimzo.app', 'android.intent.category.LAUNCHER',
                     'flutter_deeplinking_enabled', 'io.nimzo.app.apk_updates'):
        assert expected in manifest, f'Missing manifest contract: {expected}'
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None, 'APK ZIP integrity failure'
        for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64'):
            for library in ('libvivox_bridge.so', 'libvivox-sdk.so'):
                assert archive.read(f'lib/{abi}/{library}')[:4] == b'\x7fELF', 'Invalid native library'
    subprocess.run([str(tools / 'zipalign'), '-c', '-P', '16', '4', str(apk)], check=True)
    for script in ('verify_vivox_callback.py', 'verify_vivox_login.py'):
        subprocess.run([sys.executable, str(root / 'tools' / script), str(apk)], check=True)
    apk.with_suffix('.apk.signing.txt').write_text(signature)
    print('Installable TEST APK verified:', hashlib.sha256(apk.read_bytes()).hexdigest())


if __name__ == '__main__':
    verify(Path(sys.argv[1]))

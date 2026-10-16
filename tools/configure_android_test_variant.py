"""Opt-in side-by-side APK; never replace an existing Nimzo installation."""
import argparse
from pathlib import Path
import re


def configure(android: Path):
    gradle = android / 'app/build.gradle.kts'
    manifest = android / 'app/src/main/AndroidManifest.xml'
    build, count = re.subn(r'applicationId\s*=\s*"io\.nimzo\.app(?:\.test)?"',
                           'applicationId = "io.nimzo.app.test"', gradle.read_text())
    if count != 1:
        raise ValueError('Expected one Nimzo application ID; no files changed')
    xml = manifest.read_text()
    xml = xml.replace('android:label="Nimzo"', 'android:label="Nimzo Test"')
    xml = xml.replace('android:name=".MainActivity"', 'android:name="io.nimzo.app.MainActivity"')
    xml = xml.replace('android:authorities="io.nimzo.app.apk_updates"',
                      'android:authorities="${applicationId}.apk_updates"')
    for required in ('android:label="Nimzo Test"', 'android:name="io.nimzo.app.MainActivity"',
                     'android:authorities="${applicationId}.apk_updates"'):
        if required not in xml:
            raise ValueError('Missing test identity contract: ' + required)
    # Compress native libraries to reduce interrupted mobile downloads. Android
    # extracts them at install time; retain every ABI and all feature assets.
    if "// Compact Nimzo test APK" not in build:
        build += "\n// Compact Nimzo test APK\nandroid { packaging { jniLibs { useLegacyPackaging = true } } }\n"
    gradle.write_text(build)
    manifest.write_text(xml)
    print('Side-by-side test identity: io.nimzo.app.test; native namespace preserved')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('android', type=Path)
    configure(parser.parse_args().android)

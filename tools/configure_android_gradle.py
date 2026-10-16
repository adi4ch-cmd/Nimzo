#!/usr/bin/env python3
"""Pin generated Android projects to the API-36-compatible AGP 8 toolchain.

Flutter 3.47 generates AGP 9 but disables built-in Kotlin for older plugins.
file_picker 11 detects AGP 9 and skips KGP, leaving its Kotlin class unbuilt.
AGP 8.11.1 supports API 36 and consistently uses the external Kotlin plugin.
"""
import argparse
from pathlib import Path
import re


def configure(android: Path):
    settings = android / 'settings.gradle.kts'
    value = settings.read_text()
    for plugin, version in [('com.android.application', '8.11.1'),
                            ('org.jetbrains.kotlin.android', '2.2.20')]:
        pattern = r'(id\("' + re.escape(plugin) + r'"\) version )"[^"]+"'
        value, count = re.subn(pattern, lambda m: m[1] + '"' + version + '"', value)
        if count != 1:
            raise ValueError(f'Expected one generated {plugin} declaration')
    wrapper = android / 'gradle/wrapper/gradle-wrapper.properties'
    distribution, count = re.subn(r'gradle-[0-9.]+-(all|bin)\.zip',
                                  r'gradle-8.14.3-\1.zip', wrapper.read_text())
    if count != 1:
        raise ValueError('Expected one Gradle distribution URL')
    settings.write_text(value)
    wrapper.write_text(distribution)
    print('Android toolchain: AGP 8.11.1 / Kotlin 2.2.20 / Gradle 8.14.3')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('android', type=Path)
    configure(parser.parse_args().android)

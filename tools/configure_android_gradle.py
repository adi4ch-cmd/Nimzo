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
    app = android / 'app/build.gradle.kts'
    if app.exists():
        application = app.read_text()
        # AGP 9 templates rely on built-in Kotlin and omit its application.
        # After pinning AGP 8, apply KGP before Flutter configures Kotlin tasks.
        if not re.search(r'id\("(?:org\.jetbrains\.kotlin\.android|kotlin-android)"\)', application):
            application, count = re.subn(
                r'(?m)^(\s*)id\("dev\.flutter\.flutter-gradle-plugin"\)',
                lambda m: m[1] + 'id("org.jetbrains.kotlin.android")\n' + m[0],
                application,
            )
            if count != 1:
                raise ValueError('Expected one Flutter Gradle plugin application')
        app.write_text(application)
    properties = android / 'gradle.properties'
    if properties.exists():
        values = properties.read_text()
        # Generated 8G heap + 4G metaspace exceeds common CI/container limits.
        # Leave room for Kotlin, native compilation and the Flutter compiler.
        for key, setting in {
            'org.gradle.jvmargs': '-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError',
            'org.gradle.workers.max': '2',
            'org.gradle.parallel': 'false',
            'kotlin.daemon.jvmargs': '-Xmx768m',
        }.items():
            pattern = r'(?m)^' + re.escape(key) + r'=.*$'
            if re.search(pattern, values):
                values = re.sub(pattern, lambda _: key + '=' + setting, values)
            else:
                values = values.rstrip() + '\n' + key + '=' + setting + '\n'
        properties.write_text(values)
    settings.write_text(value)
    wrapper.write_text(distribution)
    print('Android toolchain: AGP 8.11.1 / Kotlin 2.2.20 / Gradle 8.14.3')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('android', type=Path)
    configure(parser.parse_args().android)

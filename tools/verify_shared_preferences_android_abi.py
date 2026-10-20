#!/usr/bin/env python3
"""Verify the compiled preferences ABI for the reviewed lockfile generation.

Pigeon 2.4.28 and JNI 2.5.1 have different native entrypoints. Both must retain
exact compiled signatures and Kotlin classes, with emulator startup checked
separately by the build. Unknown plugin versions fail closed.

Usage: python3 tools/verify_shared_preferences_android_abi.py path/to/app.apk
"""
import re
import struct
import sys
import zipfile
from pathlib import Path

PREFIX = "Lio/flutter/plugins/sharedpreferences/"


def required_signatures(version):
    # 2.4.28 uses Pigeon platform channels; it has no JNI Registrar class.
    # The 2.5.1 JNI generation instead needs the Kotlin suspend signature.
    if version == "2.4.28":
        return [
            (PREFIX + "LegacySharedPreferencesPlugin;", "Ljava/util/Map;",
             ("Ljava/lang/String;", "Ljava/util/List;")),
            (PREFIX + "SharedPreferencesPlugin;", "Ljava/util/Map;",
             ("Ljava/util/List;", PREFIX + "SharedPreferencesPigeonOptions;")),
        ]
    if version == "2.5.1":
        return [(PREFIX + "SharedPreferencesApiRegistrar;", "Ljava/lang/Object;",
                 ("Ljava/lang/String;", "Ljava/util/List;",
                  "Lkotlin/coroutines/Continuation;"))]
    raise ValueError("Unreviewed shared_preferences_android version: " + version)


def validate_signatures(version, signatures):
    missing = set(required_signatures(version)) - set(signatures)
    if missing:
        raise ValueError("shared_preferences_android " + version +
                         " compiled ABI mismatch; missing " + repr(sorted(missing)))



def dex_methods(data):
    if not data.startswith(b"dex\n"):
        raise ValueError("Invalid DEX header")
    u32 = lambda offset: struct.unpack_from("<I", data, offset)[0]

    def uleb128(offset):
        value = 0
        for i in range(5):
            byte = data[offset + i]
            value |= (byte & 0x7f) << (7 * i)
            offset += 1
            if byte < 0x80:
                return offset
        raise ValueError("Invalid DEX ULEB128")

    number, offset = u32(0x38), u32(0x3c)
    strings = []
    for i in range(number):
        pos = uleb128(u32(offset + i * 4))
        end = data.find(b"\0", pos)
        if end < 0:
            raise ValueError("Invalid DEX string")
        strings.append(data[pos:end].decode("utf-8", errors="replace"))

    number, offset = u32(0x40), u32(0x44)
    types = [strings[u32(offset + i * 4)] for i in range(number)]

    number, offset = u32(0x48), u32(0x4c)
    protos = []
    for i in range(number):
        entry = offset + i * 12
        return_type = types[u32(entry + 4)]
        parameters_offset = u32(entry + 8)
        parameters = []
        if parameters_offset:
            count = u32(parameters_offset)
            parameters = [
                types[struct.unpack_from(
                    "<H", data, parameters_offset + 4 + k * 2)[0]]
                for k in range(count)
            ]
        protos.append((return_type, parameters))

    number, offset = u32(0x58), u32(0x5c)
    for i in range(number):
        class_idx, proto_idx, name_idx = struct.unpack_from(
            "<HHI", data, offset + i * 8)
        if types[class_idx].startswith(PREFIX) and strings[name_idx] == "getAll":
            return_type, parameters = protos[proto_idx]
            yield (types[class_idx], return_type, tuple(parameters))


def verify(path: Path):
    lock = (Path(__file__).resolve().parents[1] / "nimzo/pubspec.lock").read_text()
    match = re.search(r'(?ms)^  shared_preferences_android:\n(?:(?!^  \w).)*?^    version: "([^"]+)"', lock)
    if not match:
        raise ValueError("Cannot determine reviewed Android preferences plugin version")
    version = match.group(1)
    required_signatures(version)
    with zipfile.ZipFile(path) as apk:
        if apk.testzip() is not None:
            raise ValueError("APK ZIP CRC verification failed")
        files = [n for n in apk.namelist()
                 if n.startswith("classes") and n.endswith(".dex")]
        if not files:
            raise ValueError("APK does not have any DEX classes")
        signatures = [
            signature
            for name in files
            for signature in dex_methods(apk.read(name))
        ]
        # The following class was absent in the previous APK after R8 and
        # made the JNI bridge throw ClassNotFoundException at startup.
        kotlin_result_descriptor = b"Lkotlin/Result;"
        if not any(kotlin_result_descriptor in apk.read(name)
                   for name in files):
            raise ValueError("kotlin.Result missing from compiled APK DEX")
        validate_signatures(version, signatures)
    print("PASS: compiled shared_preferences_android " + version + " ABI matches lockfile")



if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: verify_shared_preferences_android_abi.py APK")
    try:
        verify(Path(sys.argv[1]))
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        raise SystemExit(f"FAIL: Android startup ABI is broken: {error}") from error

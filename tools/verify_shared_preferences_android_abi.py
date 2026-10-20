#!/usr/bin/env python3
"""Fail-closed check for the specific Kotlin coroutine ABI broken in NIMZO.

The release-mode R8 output must preserve the signature invoked by the
shared_preferences Android JNI bridge during Supabase.initialize. This checks
the COMPILED classes.dex, not just ProGuard text or a debug build.

Usage: python3 tools/verify_shared_preferences_android_abi.py path/to/app.apk
"""
import struct
import sys
import zipfile
from pathlib import Path

EXPECTED_CLASS = "Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;"
EXPECTED_METHOD = "getAll"
EXPECTED_RETURN = "Ljava/lang/Object;"
EXPECTED_PARAMS = [
    "Ljava/lang/String;",
    "Ljava/util/List;",
    "Lkotlin/coroutines/Continuation;",
]


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
        if types[class_idx] == EXPECTED_CLASS and strings[name_idx] == EXPECTED_METHOD:
            yield protos[proto_idx]


def verify(path: Path):
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
        if (EXPECTED_RETURN, EXPECTED_PARAMS) not in signatures:
            raise ValueError(
                "shared_preferences JNI ABI mismatch: expected "
                "SharedPreferencesApiRegistrar.getAll(String,List,"
                "kotlin.coroutines.Continuation)Object, found "
                + repr(signatures)
            )
    print("PASS: shared_preferences Kotlin Continuation ABI preserved in APK")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: verify_shared_preferences_android_abi.py APK")
    try:
        verify(Path(sys.argv[1]))
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        raise SystemExit(f"FAIL: Android startup ABI is broken: {error}") from error

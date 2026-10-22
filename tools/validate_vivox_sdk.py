#!/usr/bin/env python3
"""Read-only SDK consistency checks. Does not extract, compile or upload SDK files.

This verifies packaging inputs, not SDK licensing, header/API version identity,
dynamic symbol linkage, Java method signatures, or working microphone audio.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile


ABI_ELF = {'arm64-v8a': (2, 183), 'armeabi-v7a': (1, 40), 'x86_64': (2, 62), 'x86': (1, 3)}
HEADERS = ('Vxc.h', 'VxcTypes.h', 'VxcErrors.h', 'VxcRequests.h', 'VxcResponses.h', 'VxcEvents.h')
NATIVE_NAMES = ('libvivox-sdk.so', 'libvivoxsdk.so')
MAX_ARCHIVE_MEMBER = 256 * 1024 * 1024


def validate_elf(data: bytes, abi: str) -> None:
    if abi not in ABI_ELF:
        raise ValueError(f'Unsupported ABI: {abi}')
    bits, machine = ABI_ELF[abi]
    size = 64 if bits == 2 else 52
    if len(data) < size or data[:4] != b'\x7fELF':
        raise ValueError('Truncated or invalid ELF header')
    if tuple(data[4:7]) != (bits, 1, 1):
        raise ValueError(f'ELF class/encoding does not match ABI {abi}')
    kind, actual_machine, version = struct.unpack_from('<HHI', data, 16)
    if actual_machine != machine:
        raise ValueError(f'ELF machine does not match ABI {abi}')
    if kind != 3:
        raise ValueError('ELF must be a shared object (ET_DYN)')
    if version != 1 or struct.unpack_from('<H', data, 52 if bits == 2 else 40)[0] != size:
        raise ValueError('Invalid ELF version/header size')


def archive_member(archive: zipfile.ZipFile, name: str) -> bytes:
    entries = [entry for entry in archive.infolist() if entry.filename == name]
    if len(entries) != 1:
        raise ValueError(f'Archive must contain exactly one {name}')
    if entries[0].file_size > MAX_ARCHIVE_MEMBER:
        raise ValueError(f'Archive member too large: {name}')
    return archive.read(entries[0])


def validate_sdk(header: Path, aar: Path, native: Path, abi: str = 'arm64-v8a') -> dict:
    header, aar, native = map(Path, (header, aar, native))
    if header.name != 'Vxc.h':
        raise ValueError('Main header must be Vxc.h')
    for name in HEADERS:
        path = header.parent / name
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f'Missing or empty sibling header: {name}')
    if not native.is_file() or native.stat().st_size > MAX_ARCHIVE_MEMBER:
        raise ValueError('Native library missing or too large')
    data = native.read_bytes()
    validate_elf(data, abi)
    try:
        with zipfile.ZipFile(aar) as archive:
            classes = archive_member(archive, 'classes.jar')
            with zipfile.ZipFile(io.BytesIO(classes)) as jar:
                archive_member(jar, 'com/vivox/sdk/JniHelpers.class')
            candidates = [f'jni/{abi}/{name}' for name in NATIVE_NAMES
                          if f'jni/{abi}/{name}' in archive.namelist()]
            if not candidates:
                raise ValueError(f'AAR has no Vivox native library for ABI {abi}')
            for name in candidates:
                packaged = archive_member(archive, name)
                validate_elf(packaged, abi)
                if packaged != data:
                    raise ValueError('AAR and loose native library do not match; select one SDK release')
    except (OSError, zipfile.BadZipFile, KeyError) as error:
        raise ValueError(f'Invalid or unreadable SDK archive ({type(error).__name__})') from None
    with aar.open('rb') as stream:
        digest = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
        aar_digest = digest.hexdigest()
    return {'abi': abi, 'header': str(header), 'aar': str(aar), 'native': str(native),
            'native_sha256': hashlib.sha256(data).hexdigest(),
            'aar_sha256': aar_digest}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('header', 'aar', 'native'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--abi', default='arm64-v8a', choices=ABI_ELF)
    args = parser.parse_args()
    try:
        result = validate_sdk(args.header, args.aar, args.native, args.abi)
    except (OSError, ValueError) as error:
        parser.exit(1, f'SDK validation FAILED: {error}\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

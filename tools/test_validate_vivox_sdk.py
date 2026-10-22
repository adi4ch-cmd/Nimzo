"""Synthetic SDK fixtures; no vendor SDK bytes or application builds."""
import io
from pathlib import Path
import struct
import shutil
import subprocess
import tempfile
import unittest
import zipfile

import validate_vivox_sdk as validator


def elf(machine=183, bits=2):
    data = bytearray(64 if bits == 2 else 52)
    data[:7] = b'\x7fELF' + bytes((bits, 1, 1))
    struct.pack_into('<HHI', data, 16, 3, machine, 1)
    struct.pack_into('<H', data, 52 if bits == 2 else 40, len(data))
    return bytes(data)


class SDKValidation(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name in ('Vxc.h', 'VxcErrors.h', 'VxcTypes.h', 'VxcRequests.h', 'VxcResponses.h', 'VxcEvents.h'):
            (self.root / name).write_text('/* synthetic header */')
        self.native = self.root / 'libvivox-sdk.so'
        self.native.write_bytes(elf())
        self.aar = self.root / 'sdk-release.aar'
        self.archive()

    def archive(self, native=None, abi='arm64-v8a', helper=True):
        jar = io.BytesIO()
        with zipfile.ZipFile(jar, 'w') as z:
            if helper: z.writestr('com/vivox/sdk/JniHelpers.class', b'synthetic-class')
        with zipfile.ZipFile(self.aar, 'w') as z:
            z.writestr('classes.jar', jar.getvalue())
            z.writestr(f'jni/{abi}/libvivox-sdk.so', self.native.read_bytes() if native is None else native)

    def validate(self):
        return validator.validate_sdk(self.root / 'Vxc.h', self.aar, self.native)

    def test_valid_matching_arm64_sdk(self):
        self.assertEqual(self.validate()['abi'], 'arm64-v8a')

    def test_rejects_x86_64_file_in_arm64_directory(self):
        self.native.write_bytes(elf(machine=62))
        self.archive()
        with self.assertRaisesRegex(ValueError, 'ABI'): self.validate()

    def test_rejects_mismatched_aar_and_loose_library(self):
        self.archive(native=elf() + b'different release')
        with self.assertRaisesRegex(ValueError, 'match'): self.validate()

    def test_rejects_missing_requested_aar_abi(self):
        self.archive(abi='x86_64')
        with self.assertRaisesRegex(ValueError, 'arm64-v8a'): self.validate()

    def test_rejects_missing_java_helper(self):
        self.archive(helper=False)
        with self.assertRaisesRegex(ValueError, 'JniHelpers'): self.validate()

    def test_rejects_missing_sibling_header(self):
        (self.root / 'VxcErrors.h').unlink()
        with self.assertRaisesRegex(ValueError, 'VxcErrors.h'): self.validate()

    def test_rejects_truncated_elf(self):
        self.native.write_bytes(b'\x7fELF')
        with self.assertRaisesRegex(ValueError, 'ELF'): self.validate()

    def test_rejects_executable_instead_of_shared_library(self):
        data = bytearray(elf()); struct.pack_into('<H', data, 16, 2)
        self.native.write_bytes(data)
        with self.assertRaisesRegex(ValueError, 'shared'): self.validate()

    def test_rejects_duplicate_archive_members(self):
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            with zipfile.ZipFile(self.aar, 'a') as z:
                z.writestr('jni/arm64-v8a/libvivox-sdk.so', elf())
        with self.assertRaisesRegex(ValueError, 'exactly one'): self.validate()

    def test_cmake_rejects_cross_abi_and_ambiguous_releases(self):
        if not shutil.which('cmake'): self.skipTest('cmake unavailable')
        production = Path(__file__).resolve().parents[1] / 'nimzo/native/vivox/android/CMakeLists.txt'
        # Configure only: no cmake --build, SDK compilation or app packaging.
        source = self.root / 'source'; source.mkdir()
        (source / 'CMakeLists.txt').write_text(production.read_text())
        (source / 'vivox_bridge.cpp').write_text('// synthetic source, never compiled')
        sdk = self.root / 'sdk'; sdk.mkdir()
        headers = sdk / 'include'; headers.mkdir()
        for name in validator.HEADERS: (headers / name).write_text('/* synthetic */')
        foreign = sdk / 'x86_64'; foreign.mkdir()
        (foreign / 'libvivox-sdk.so').write_bytes(elf(62))
        def configure(label):
            return subprocess.run(['cmake', '-S', str(source), '-B', str(self.root / label),
                                   '-DVIVOX_SDK_ROOT=' + str(sdk), '-DCMAKE_ANDROID_ARCH_ABI=arm64-v8a'],
                                  capture_output=True, text=True)
        wrong = configure('wrong')
        self.assertNotEqual(wrong.returncode, 0)
        self.assertIn('no cross-ABI fallback', wrong.stderr)
        right = sdk / 'arm64-v8a'; right.mkdir()
        (right / 'libvivox-sdk.so').write_bytes(elf())
        matched = configure('matched')
        self.assertEqual(matched.returncode, 0, matched.stderr)
        extra = sdk / 'other-release' / 'arm64-v8a'; extra.mkdir(parents=True)
        (extra / 'libvivox-sdk.so').write_bytes(elf())
        ambiguous = configure('ambiguous')
        self.assertNotEqual(ambiguous.returncode, 0)
        self.assertIn('exactly one Vivox library', ambiguous.stderr)


if __name__ == '__main__':
    unittest.main()

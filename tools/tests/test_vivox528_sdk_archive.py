"""Source-only Vivox 5.28.0 regression tests; no proprietary SDK required."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "nimzo_vivox_builder", ROOT / "tools/build_codespace_vivox_dynamic.py"
)
assert SPEC is not None and SPEC.loader is not None
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)

PACKAGE = "vivox-sdk-5.28.0.34030.504b30c0"
SDK = f"{PACKAGE}/SDK"


class Vivox528ReleaseSelectionTest(unittest.TestCase):
    def create_sdk_tree(self, dest):
        root = dest / PACKAGE / "SDK"
        for name, data in (
            ("include/Vxc.h", b"official-header"),
            ("aar/sdk-release.aar", b"official-aar"),
            ("Libraries/Release/arm64-v8a/libvivox-sdk.so", b"unstripped-release"),
            ("Libraries/Debug/arm64-v8a/libvivox-sdk.so", b"debug"),
            ("Libraries/Stripped/Debug/arm64-v8a/libvivox-sdk.so", b"stripped-debug"),
            ("Libraries/Stripped/Release/armeabi-v7a/libvivox-sdk.so", b"wrong-abi"),
            ("Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so", b"aar-matched"),
        ):
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        return root

    def test_selects_exact_aar_mached_stripped_arm64_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.create_sdk_tree(Path(directory))
            header, aar, native = builder.sdk_files(Path(directory))
            self.assertEqual(header, root / "include/Vxc.h")
            self.assertEqual(aar, root / "aar/sdk-release.aar")
            self.assertEqual(native.read_bytes(), b"aar-matched")
            self.assertEqual(native, root / "Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so")

    def test_rejects_unstripped_release_when_matched_release_absent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.create_sdk_tree(Path(directory))
            (root / "Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so").unlink()
            self.assertIsNone(builder.sdk_files(Path(directory)))

    def test_zip_extracts_only_release_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "vendor-5.28.0.zip"
            files = {
                f"{SDK}/include/Vxc.h": b"header",
                f"{SDK}/include/VxcErrors.h": b"errors",
                f"{SDK}/aar/sdk-release.aar": b"aar",
                f"{SDK}/Libraries/Stripped/Release/arm64-v8a/libvivox-sdk.so": b"release",
                f"{SDK}/Libraries/Release/arm64-v8a/libvivox-sdk.so": b"large-debug-symbol-file",
                f"{SDK}/Libraries/Debug/arm64-v8a/libvivox-sdk.so": b"debug",
                f"{PACKAGE}/SDKSampleApp/Prebuilt/Release/SDKSampleApp.apk": b"sample",
            }
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
                for path, data in files.items():
                    output.writestr(path, data)
            found_root, header, aar, native = builder.sdk_location(
                str(archive), root / "temporary"
            )
            self.assertEqual(found_root.name, "SDK")
            self.assertEqual(header.read_bytes(), b"header")
            self.assertEqual(aar.read_bytes(), b"aar")
            self.assertEqual(native.read_bytes(), b"release")
            self.assertFalse(
                (found_root / "Libraries/Release/arm64-v8a/libvivox-sdk.so").exists()
            )
            self.assertFalse(
                (found_root.parent / "SDKSampleApp/Prebuilt/Release/SDKSampleApp.apk").exists()
            )

    def test_cmake_uses_only_aar_matched_variant(self):
        source = (ROOT / "nimzo/native/vivox/android/CMakeLists.txt").read_text()
        self.assertIn("Libraries/Stripped/Release/", source)
        self.assertIn("CMAKE_ANDROID_ARCH_ABI", source)
        self.assertNotIn("GLOB_RECURSE VIVOX_LIB_FILES", source)
        self.assertIn("target_link_libraries(vivox_bridge", source)


if __name__ == "__main__":
    unittest.main()

"""Source-only regression for Codespace SDK selection. No proprietary SDK used."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "build_codespace_vivox_dynamic.py"
SPEC = importlib.util.spec_from_file_location("nimzo_codespace_vivox", SCRIPT)
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class VivoxSelectionTests(unittest.TestCase):
    def content(self, relative):
        if relative.endswith("libvivox-sdk.so"):
            return b"matching-stripped-arm64"
        if relative.endswith(".aar"):
            return b"matching-sdk-aar"
        return relative.encode("ascii")

    def test_zip_stages_only_matching_release_native_library(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            filename = root / "vivox-5.28.0.zip"
            prefix = "vivox-sdk-5.28.0.34030.504b30c0/SDK/"
            with zipfile.ZipFile(filename, "w") as archive:
                for relative in BUILDER.SDK_COMPONENTS:
                    archive.writestr(prefix + relative, self.content(relative))
                archive.writestr(prefix + "Libraries/Release/arm64-v8a/libvivox-sdk.so",
                                 b"mismatch-unstripped")
                archive.writestr(prefix + "Libraries/Stripped/Debug/arm64-v8a/libvivox-sdk.so",
                                 b"mismatch-debug")
            sdk_root, header, aar, native = BUILDER.sdk_location(
                str(filename), root / "temp"
            )
            self.assertTrue(header.is_file())
            self.assertEqual(aar.read_bytes(), b"matching-sdk-aar")
            self.assertEqual(native.read_bytes(), b"matching-stripped-arm64")
            self.assertEqual(len(list(sdk_root.rglob("*.so"))), 1)
            self.assertFalse((sdk_root / "Libraries/Release").exists())
            self.assertTrue(filename.exists())

    def test_unpacked_sdk_uses_same_release_pair(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            original_sdk = root / "source/SDK"
            for relative in BUILDER.SDK_COMPONENTS:
                f = original_sdk / relative
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_bytes(self.content(relative))
            _, _, aar, native = BUILDER.sdk_location(
                str(root / "source"), root / "temp"
            )
            self.assertEqual(aar.read_bytes(), b"matching-sdk-aar")
            self.assertEqual(native.read_bytes(), b"matching-stripped-arm64")
            self.assertTrue((original_sdk / "include/Vxc.h").is_file())

    def test_missing_release_file_fails_without_mutating_source(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            original = root / "incomplete.zip"
            with zipfile.ZipFile(original, "w") as archive:
                archive.writestr("SDK/include/Vxc.h", b"some-header")
            with self.assertRaises(RuntimeError):
                BUILDER.sdk_location(str(original), root / "temp")
            self.assertTrue(original.is_file())


if __name__ == "__main__":
    unittest.main()

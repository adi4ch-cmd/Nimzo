"""Private SDK part reconstruction and owner QA authorization regression tests."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools/build_drive_vivox_qa.py"
SPEC = importlib.util.spec_from_file_location("drive_vivox_qa", SCRIPT)
assert SPEC and SPEC.loader
qa = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qa)


class PrivateVoiceQATest(unittest.TestCase):
    def test_all_four_parts_and_source_sha_enforced(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            parts = root / "parts"
            parts.mkdir()
            blobs = [b"ABC", b"DEF", b"GHI", b"JKL"]
            whole = b"".join(blobs)
            manifest = {
                "source_filename": "com.custom.android.vivox.vivoxCoreAndroidSdk-5.28.0.zip",
                "source_size_bytes": len(whole),
                "source_sha256": hashlib.sha256(whole).hexdigest(),
                "parts": []
            }
            for i, blob in enumerate(blobs):
                name = f"android-vivox-5.28.0.zip.part{i:03d}"
                (parts / name).write_bytes(blob)
                manifest["parts"].append({
                    "name": name, "bytes": len(blob),
                    "sha256": hashlib.sha256(blob).hexdigest()
                })
            (parts / "NIMZO_Vivox_parts_manifest.json").write_text(json.dumps(manifest))
            original_size, original_sha = qa.ANDROID_SDK_SIZE, qa.ANDROID_SDK_SHA256
            original_zip, original_badzip = qa.zipfile.ZipFile, qa.zipfile.BadZipFile
            try:
                qa.ANDROID_SDK_SIZE = len(whole)
                qa.ANDROID_SDK_SHA256 = hashlib.sha256(whole).hexdigest()

                # Deliberately use a synthetic stream, not a real vendor archive;
                # mock ZIP integrity check only for test reconstruction.
                from unittest.mock import patch
                with patch.object(qa.zipfile, "ZipFile") as archive:
                    archive.return_value.__enter__.return_value.testzip.return_value = None
                    qa.reconstruct_sdk(parts, root / "assembled.zip")
                self.assertEqual((root / "assembled.zip").read_bytes(), whole)

                (parts / "android-vivox-5.28.0.zip.part002").write_bytes(b"XXI")
                with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                    with patch.object(qa.zipfile, "ZipFile"):
                        qa.reconstruct_sdk(parts, root / "bad.zip")
            finally:
                qa.ANDROID_SDK_SIZE = original_size
                qa.ANDROID_SDK_SHA256 = original_sha

    def test_qa_gate_does_not_claim_production_release(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / "release").mkdir()
            room = root / "nimzo/lib/features/rooms/domain"
            room.mkdir(parents=True)
            (room / "room.dart").write_text("static const count = 10;")
            checks = {n: {"status": "PASS", "evidence": ["test-result"]}
                      for n in qa.QA_CHECKS}
            record = {
                "qa_build_authorized": True, "qa_open_blockers": [],
                "build_authorized": False, "voice_enabled": False,
                "qa_checks": checks
            }
            (root / "release/acceptance.json").write_text(json.dumps(record))
            qa.verify_qa_authorization(root)
            record["qa_checks"]["store_backpack"]["status"] = "BLOCKED"
            (root / "release/acceptance.json").write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "store_backpack"):
                qa.verify_qa_authorization(root)

    def test_never_publishes_sdk_or_skips_runtime_disclaimer(self):
        source = SCRIPT.read_text()
        self.assertNotIn("gh release create", source)
        self.assertNotIn("gh release upload", source)
        self.assertIn('"real_two_user_audio": "NOT YET VERIFIED"', source)
        self.assertIn('"android_device_startup": "NOT YET VERIFIED"', source)
        self.assertIn("verify_apk(apk)", source)
        self.assertIn("validate_sdk(header, aar, native", source)


if __name__ == "__main__":
    unittest.main()

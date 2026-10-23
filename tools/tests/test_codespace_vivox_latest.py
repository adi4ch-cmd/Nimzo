import ast
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools/build_codespace_vivox_dynamic.py"


class CodespaceVivoxLatestTests(unittest.TestCase):
    def setUp(self):
        self.source = BUILDER.read_text()
        ast.parse(self.source)

    def test_targets_current_ten_mic_source(self):
        self.assertIn(
            'REPO_BRANCH = "feature/falla-levels-v142-20261024"',
            self.source,
        )
        self.assertIn('"test/room_seat_repository_test.dart"', self.source)
        self.assertIn('"test/room_profile_premium_layout_test.dart"', self.source)
        room = (
            ROOT / "nimzo/lib/features/rooms/domain/room.dart"
        ).read_text()
        self.assertIn("static const count = 10;", room)

    def test_detects_codespace_sdk_without_uploading_proprietary_zip(self):
        self.assertIn(
            "com.custom.android.vivox.vivoxCoreAndroidSdk-5.28.0.zip",
            self.source,
        )
        self.assertIn("if args.check_sdk_only:", self.source)
        self.assertIn("sdk_location(args.sdk_root, tmp_parent)", self.source)
        self.assertIn("git\", \"worktree\", \"add\", \"--detach", self.source)
        self.assertNotIn("gh release upload", self.source)
        self.assertNotIn("git add", self.source)
        self.assertIn("verify_prebuild_acceptance.py", self.source)

    def test_derives_current_apk_name_from_pubspec(self):
        self.assertIn("match.group(1)", self.source)
        self.assertIn("VIVOX528_ARM64_QA_", self.source)
        self.assertRegex((ROOT / "nimzo/pubspec.yaml").read_text(),
                         r"(?m)^version: 1\.0\.43\+143$")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Fast self-contained regression tests for safe NIMZO archive staging."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from stage_apk_store_assets import (
    ApkSources, category_for, discover_from_full_audit,
    read_candidates, source_parts, verify_structural_media,
)


class NIMZOStoreApkTests(unittest.TestCase):
    def test_path_traversal_and_archive_rejected(self):
        self.assertIsNone(source_parts("base.apk!/../private.key"))
        self.assertIsNone(source_parts("base.apk!/assets/../../private.key"))
        self.assertIsNone(source_parts("base.apk!/assets\\hidden.svga"))
        self.assertIsNone(source_parts("base.apks!/assets/item.svga"))
        self.assertEqual(source_parts("base.apk!/assets/frame_avatar.svga"),
                         ("base.apk", "assets/frame_avatar.svga"))

    def test_real_store_names_are_distinct_from_icons_and_game_effects(self):
        self.assertEqual(category_for("assets/room_avatar_frame.svga", "svga"),
                         "Avatar Frame")
        self.assertEqual(category_for("assets/chat_bubble_effect.svga", "svga"),
                         "Chat Bubble")
        self.assertEqual(category_for("assets/room_theme_magic.png", "png"),
                         "Party Theme")
        self.assertEqual(category_for("assets/mic_wave.svga", "svga"),
                         "Mic Wave")
        self.assertEqual(category_for("assets/car_entrance.svga", "svga"),
                         "Rides")
        self.assertIsNone(category_for("assets/ludo_entrance.svga", "svga"))
        self.assertIsNone(category_for("assets/leaderboard/rank1.svga", "svga"))
        self.assertIsNone(category_for("assets/agency_owner_frame.svga", "svga"))
        self.assertIsNone(category_for("assets/store_tab_frame.png", "png"))
        self.assertIsNone(category_for("assets/chat_list_gold_anim.svga", "svga"))
        self.assertIsNone(category_for("assets/vip_avatar_frame.svga", "svga"))
        self.assertIsNone(category_for("res/drawable-xhdpi-v4/ic_avatar_frame.png", "png"))
        self.assertIsNone(category_for("assets/icons/gold_avatar_frame.png", "png"))
        self.assertIsNone(category_for("assets/store_tab_avatar_frame.png", "png"))
        self.assertIsNone(category_for("assets/2.0x/avatar_frame.webp", "webp"))
        self.assertIsNone(category_for("assets/game_entrance.svga", "svga"))

    def test_svga_structure_and_corrupted_bytes(self):
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as z:
            z.writestr("movie.binary", b"\x08\x01" * 20)
            z.writestr("images/banner.png", b"\x89PNG\r\n\x1a\n")
        self.assertEqual(
            verify_structural_media(buf.getvalue(), "svga")[0], "svga")
        with self.assertRaises(ValueError):
            verify_structural_media(b"garbage", "svga")
        with self.assertRaises(ValueError):
            verify_structural_media(b"RIFFfake", "webp")

    def test_mp4_requires_alpha_metadata_before_classifying_vap(self):
        video = b"\x00\x00\x00\x18ftypisom" + b"\0"*60
        with self.assertRaises(ValueError):
            verify_structural_media(video, "mp4")
        self.assertEqual(
            verify_structural_media(video+b"vapc", "mp4")[0], "vap")

    def test_nested_apks_sha256_and_original_length(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            data = b"\x89PNG\r\n\x1a\n" + b"payload"
            inner = io.BytesIO()
            with zipfile.ZipFile(inner, "w", compression=zipfile.ZIP_DEFLATED) as z:
                z.writestr("assets/room_theme_magic.png", data)
            with zipfile.ZipFile(root/"source.apks", "w") as z:
                z.writestr("base.apk", inner.getvalue())
            meta = {
                "source_package": "source.apks",
                "source": "base.apk!/assets/room_theme_magic.png",
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
            }
            with ApkSources(root) as source:
                self.assertEqual(source.payload(meta), data)
                self.assertEqual(source.payload(meta), data)
                with self.assertRaises(ValueError):
                    source.payload({**meta, "sha256": "0"*64})
                with self.assertRaises(ValueError):
                    source.payload({**meta, "bytes": len(data)+1})

    def test_full_audit_only_collects_strict_store_candidates(self):
        with tempfile.TemporaryDirectory() as folder:
            full = Path(folder)/"inventory.json.gz"
            payload = {
                "packages": [{
                    "filename": "Example.apks",
                    "files": [
                        {"source": "base.apk!/assets/room_theme_aurora.svga",
                         "format": "svga", "sha256": "a"*64,
                         "bytes": 200},
                        {"source": "base.apk!/assets/game_entrance.svga",
                         "format": "svga", "sha256": "b"*64,
                         "bytes": 200, "package": "Example.apks"},
                    ],
                }],
            }
            with gzip.open(full, "wt", encoding="utf-8") as f:
                json.dump(payload, f)
            rows = discover_from_full_audit(full)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["proposed_store_category"],
                             "Party Theme")
            self.assertEqual(rows[0]["source_package"], "Example.apks")

    def test_best_source_report_is_not_permission_to_publish(self):
        with tempfile.TemporaryDirectory() as folder:
            name = Path(folder)/"source.json"
            name.write_text(json.dumps({
                "status": "CANDIDATES_ONLY",
                "categories": {"frames": [{
                    "source": "base.apk!/assets/avatar_frame_royal.svga",
                    "format": "svga", "package": "Sample.apks", "bytes": 200,
                    "sha256": "a"*64,
                    "rights": "owner asserted; per-asset scope unverified",
                }]},
            }))
            rows = read_candidates(name)
            self.assertEqual(rows[0]["proposed_store_category"],
                             "Avatar Frame")
            self.assertIn("scope unverified", rows[0]["audit_rights"])


if __name__ == "__main__":
    unittest.main()

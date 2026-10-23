"""Parser security fixtures only; these strings are never device evidence."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from generate_membership_refresh_migration import native_records, verify_proof


class RefreshNativeProofTest(unittest.TestCase):
    def setUp(self):
        self.items = [dict(id='fixture-vap', sha256='a'*64, media_kind='vap', frames=10, fps=20),
                      dict(id='fixture-svga', sha256='b'*64, media_kind='svga', frames=4, fps=20)]
        self.log = ('VERIFIED_VAP fixture-vap sha256='+'a'*64+
                    ' declared=10 rendered=10 first=0 last=9 samples=5 distinct=5 visible=5 completed=true android=true\n'
                    'VERIFIED fixture-svga sha256='+'b'*64+
                    ' frames=4 fps=20 distinct=4 visible=4 android=true\nAll tests passed!\n')

    def test_distinguishes_sampled_vap_from_every_frame_svga(self):
        records = native_records(self.log, self.items)
        self.assertEqual(records['fixture-vap']['kind'], 'vap')
        self.assertEqual(records['fixture-svga']['kind'], 'raster')

    def test_frozen_video_pixels_fail_even_with_native_frame_events(self):
        with self.assertRaisesRegex(ValueError, 'Incomplete native VAP'):
            native_records(self.log.replace('samples=5 distinct=5', 'samples=5 distinct=1'), self.items)

    def test_missing_completion_fails(self):
        with self.assertRaises(ValueError):
            native_records(self.log.replace('completed=true', 'completed=false'), self.items)

    def test_missing_svga_frame_metadata_fails(self):
        with self.assertRaisesRegex(ValueError, 'frame parameters differ'):
            native_records(self.log.replace('frames=4 fps=20', 'frames=3 fps=20'), self.items)

    def test_host_checks_never_become_android_proof(self):
        with self.assertRaises(ValueError):
            native_records(self.log.replace('android=true', 'android=false'), self.items)

    def test_duplicate_record_fails(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate native record'):
            native_records(self.log + self.log.splitlines()[1]+'\n', self.items)

    def test_zero_or_missing_source_never_verifies(self):
        with self.assertRaisesRegex(ValueError, 'Exact successful source proof required'):
            verify_proof({}, '0'*40, self.items, Path('.'))


if __name__ == '__main__':
    unittest.main()

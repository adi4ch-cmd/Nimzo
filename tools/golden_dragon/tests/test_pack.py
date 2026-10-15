import importlib.util
import json
from pathlib import Path
import struct
import unittest

SOURCE = Path(__file__).parents[1] / 'pack.py'

class PackTests(unittest.TestCase):
    def load(self):
        self.assertTrue(SOURCE.exists(), 'VAP packer has not been implemented')
        spec = importlib.util.spec_from_file_location('pack', SOURCE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_metadata_matches_color_right_alpha_left_and_native_v2_parser(self):
        pack = self.load()
        info = pack.config(540, 960, 360, 30)['info']
        self.assertEqual(info, dict(v=2, f=360, w=540, h=960,
            videoW=1088, videoH=960, orien=0, fps=30, isVapx=0,
            aFrame=[0,0,540,960], rgbFrame=[544,0,540,960]))

    def test_append_box_preserves_existing_mp4_offsets(self):
        pack = self.load()
        original = struct.pack('>I4s', 12, b'ftyp') + b'isom'
        metadata = pack.config(540,960,360,30)
        result = pack.append_config(original, metadata)
        self.assertEqual(result[:len(original)], original)
        size, kind = struct.unpack('>I4s', result[len(original):len(original)+8])
        self.assertEqual(kind,b'vapc')
        self.assertEqual(size,len(result)-len(original))
        self.assertEqual(json.loads(result[len(original)+8:]),metadata)

    def test_h264_level_covers_packed_macroblocks(self):
        pack = self.load()
        self.assertEqual(pack.h264_level(pack.config(540,960,360,30)), '4.1')
        self.assertEqual(pack.h264_level(pack.config(1080,1920,360,30)), '5.1')
        with self.assertRaises(ValueError):
            pack.h264_level(pack.config(4320,7680,360,30))

    def test_rejects_odd_yuv420_dimensions(self):
        pack = self.load()
        with self.assertRaises(ValueError): pack.config(541,960,360,30)
        with self.assertRaises(ValueError): pack.config(540,959,360,30)
        with self.assertRaises(ValueError): pack.config(540,960,0,30)

if __name__=='__main__': unittest.main()

"""Exercise real FFmpeg packing/decoding, including soft antialiased alpha."""
import importlib.util
import math
import subprocess
from pathlib import Path
import tempfile
import unittest
from PIL import Image, ImageDraw

ROOT=Path(__file__).parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/(name+'.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

class RoundTripTests(unittest.TestCase):
    def test_actual_rgba_to_h264_vap_mask_and_lossless_master(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);(folder/'rgba').mkdir()
            for f in range(1,361):
                im=Image.new('RGBA',(64,112))
                if f not in (1,360):
                    draw=ImageDraw.Draw(im)
                    x=32+int(8*math.sin(f*.03));y=56+int(15*math.cos(f*.02))
                    draw.ellipse((x-22,y-22,x+22,y+22),fill=(220,160,60,90))
                    draw.ellipse((x-18,y-18,x+18,y+18),fill=(220,160,60,255))
                im.save(folder/f'rgba/frame_{f:04}.png')
            load('pack').encode(folder)
            load('verify').check(folder)
            load('room_preview').make(folder)
            for name in ['light','dark_derived']:
                stream=load('verify').probe(folder/f'golden_dragon_room_{name}.mp4')['streams'][0]
                self.assertEqual(stream['nb_read_frames'],'360')
                self.assertEqual((stream['width'],stream['height']),(64,112))
            self.assertTrue((folder/'verification.json').is_file())
            self.assertTrue((folder/'alpha_light_vap.png').is_file())
            # A frame-count-correct opaque FFV1 must fail RGBA validation.
            opaque=folder/'opaque.mkv'
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(folder/'golden_dragon_rgba.mkv'),
                '-an','-c:v','ffv1','-pix_fmt','bgr0',str(opaque)],check=True)
            opaque.replace(folder/'golden_dragon_rgba.mkv')
            with self.assertRaisesRegex(AssertionError, 'alpha-bearing|RGBA master differs'):
                load('verify').check(folder)


if __name__=='__main__':unittest.main()

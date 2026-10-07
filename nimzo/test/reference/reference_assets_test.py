import base64
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]

class ReferenceAssetsTest(unittest.TestCase):
    def test_assets_are_exact_approved_embedded_bytes(self):
        html = (ROOT / 'nimzo-ui-1.html').read_text()
        images = json.loads(re.search(r'const IM=(\{.*?\});', html).group(1))
        for group, entries in images.items():
            for index, uri in enumerate(entries):
                media, payload = uri.split(',', 1)
                extension = media.split('/')[1].split(';')[0].replace('jpeg', 'jpg')
                path = ROOT / 'nimzo/assets/reference' / group / f'{index}.{extension}'
                self.assertTrue(path.is_file(), f'Missing approved asset: {path}')
                self.assertEqual(path.read_bytes(), base64.b64decode(payload))

if __name__ == '__main__':
    unittest.main()

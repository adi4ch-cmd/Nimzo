"""Extract approved HTML artwork without copying prototype users or economy."""
import base64
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
html = (root / 'nimzo-ui-1.html').read_text()
images = json.loads(re.search(r'const IM=(\{.*?\});', html).group(1))
assets = []
for group, entries in images.items():
    target = root / 'nimzo/assets/reference' / group
    target.mkdir(parents=True, exist_ok=True)
    for index, uri in enumerate(entries):
        media, payload = uri.split(',', 1)
        extension = media.split('/')[1].split(';')[0].replace('jpeg', 'jpg')
        path = target / f'{index}.{extension}'
        path.write_bytes(base64.b64decode(payload, validate=True))
    assets.append(f'    - assets/reference/{group}/')
manifest = root / 'nimzo/pubspec.yaml'
s = manifest.read_text().replace('    - assets/gifts/', '\n'.join(assets))
manifest.write_text(s)
print(f'Extracted {sum(map(len, images.values()))} approved assets.')

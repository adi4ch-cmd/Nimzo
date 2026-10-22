#!/usr/bin/env python3
"""Attach exact rendered thumbnails and host proof; never invent device proof."""
import hashlib
import json
import math
from pathlib import Path
import re
import sys
from PIL import Image

root = Path(__file__).resolve().parents[1]
manifest_path = root / 'nimzo/assets/drive_catalog/manifest.json'
manifest = json.loads(manifest_path.read_text())
log = Path(sys.argv[1]).read_text()
if 'All tests passed!' not in log:
    raise SystemExit('Successful renderer log required')
proof = {r[0]: r[1:] for r in re.findall(
    r'VERIFIED (\S+) sha256=([a-f0-9]{64}) frames=(\d+) fps=(\d+) distinct=(\d+) visible=(\d+) android=false', log)}
for item in manifest['items']:
    values = proof[item['id']]
    if values[0] != item['sha256']:
        raise SystemExit('Render proof does not match source hash')
    frames, fps, distinct, visible = map(int, values[1:])
    if distinct < 3 or visible <= frames // 2:
        raise SystemExit('Incomplete animation')
    png = (Path(sys.argv[2]) / (item['id'] + '.png')).read_bytes()
    sha = hashlib.sha256(png).hexdigest()
    target = root / 'nimzo/assets/drive_catalog' / (sha + '.png')
    target.write_bytes(png)
    with Image.open(target) as image:
        image.verify()
    item.update(thumbnail=f'assets/drive_catalog/{sha}.png', thumbnail_sha256=sha,
                thumbnail_bytes=len(png), duration_ms=math.ceil(1000 * frames / fps),
                frames=frames, fps=fps, host_distinct_frames=distinct,
                host_visible_frames=visible)
manifest['host_render_log_sha256'] = hashlib.sha256(log.encode()).hexdigest()
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
print('Attached verified frame previews and durations to', len(manifest['items']), 'items')

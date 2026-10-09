#!/usr/bin/env python3
"""Import original Yo2 gift UI and effects only (no Dragon or VIP/game assets).

The supplied archives contain 24 UI images and 7 lucky/super-gift SVGAs,
not the remotely downloaded, per-gift animations or gift-catalog records.
"""
from __future__ import annotations
import csv
import hashlib
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'nimzo'
SOURCE_IMAGE = 'images_gifts_vip_svip/res/mipmap-xxhdpi-v4/'
SOURCE_EFFECT = 'animations_svga/assets/'
IMAGES = {
    'anim_send_gift_v2.webp', 'ic_capsule_mic_gift.webp',
    'ic_cross_pk_sup_gift_1.webp', 'ic_cross_pk_sup_gift_2.webp',
    'ic_cross_pk_sup_gift_3.webp', 'ic_cross_pk_title_gift_sup.webp',
    'ic_daily_tasks_gift.webp', 'ic_gift_banner.webp',
    'ic_gift_effect.webp', 'ic_gift_panel_gold_arrow.webp',
    'ic_gift_pannal_sel.webp', 'ic_gift_pannal_sel_not.webp',
    'ic_gift_pannel_select_down.webp', 'ic_gift_pannel_select_up.webp',
    'ic_gift_pannel_send_up.webp', 'ic_gift_reward.webp',
    'ic_gift_voice.webp', 'ic_luck_gift_close.webp',
    'ic_moment_comment_gift.webp', 'ic_moment_gift.webp',
    'ic_treasure_gift_go.webp', 'ic_treasure_gift_icon.webp',
    'ic_user_dialog_gift.webp', 'ic_user_gift_bg.webp',
}
EFFECTS = {
    'lucky_gift_10.svga', 'lucky_gift_50.svga',
    'lucky_gift_100.svga', 'lucky_gift_1000.svga',
    'super_gift_level_one.svga', 'super_gift_level_two.svga',
    'super_gift_level_three.svga',
}
MAX_FILE = 3_000_000

def import_assets(part1: Path, part2: Path, *, dry_run: bool = False) -> int:
    wanted = {SOURCE_IMAGE + n: ('images', n) for n in IMAGES}
    wanted.update({SOURCE_EFFECT + n: ('effects', n) for n in EFFECTS})
    found: dict[str, tuple[str, str, bytes]] = {}
    for source in (part1, part2):
        with zipfile.ZipFile(source) as archive:
            bad = archive.testzip()
            if bad is not None:
                raise ValueError(f'Corrupt ZIP entry {bad}')
            for item in archive.infolist():
                if item.filename not in wanted:
                    continue
                if not 0 < item.file_size <= MAX_FILE:
                    raise ValueError(f'Invalid media size {item.filename}')
                data = archive.read(item)
                if item.filename in found:
                    if found[item.filename][2] != data:
                        raise ValueError(f'Conflicting duplicate {item.filename}')
                    continue
                group, name = wanted[item.filename]
                if group == 'images' and not (
                    data[:4] == b'RIFF' and data[8:12] == b'WEBP'
                ):
                    raise ValueError(f'Invalid WebP source {item.filename}')
                found[item.filename] = (group, name, data)
    missing = sorted(set(wanted) - set(found))
    if missing:
        raise ValueError('Missing original Yo2 gift media: ' + ', '.join(missing))

    dest_root = APP / 'assets' / 'yo2_gifts'
    for group, name, data in found.values():
        dest = dest_root / group / name
        if dest.exists() and dest.read_bytes() != data:
            raise ValueError(f'Refusing to replace modified asset {dest}')
    print(f'Verified {len(found)} original Yo2 gift files; Dragon excluded.')
    if dry_run:
        return len(found)

    pubspec = APP / 'pubspec.yaml'
    contents = pubspec.read_text(encoding='utf-8')
    anchor = '  assets:\n'
    if anchor not in contents:
        raise ValueError('Flutter assets list missing from pubspec')
    for group in ('images', 'effects'):
        entry = f'    - assets/yo2_gifts/{group}/\n'
        if entry not in contents:
            contents = contents.replace(anchor, anchor + entry, 1)
    for group, name, data in found.values():
        dest = dest_root / group / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            dest.write_bytes(data)
    manifest = dest_root / 'GIFT_ASSET_MANIFEST.csv'
    with manifest.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle)
        writer.writerow(('original_path', 'flutter_asset_path', 'sha256', 'bytes'))
        for src, (group, name, data) in sorted(found.items()):
            writer.writerow((
                src, f'assets/yo2_gifts/{group}/{name}',
                hashlib.sha256(data).hexdigest(), len(data),
            ))
    pubspec.write_text(contents, encoding='utf-8')
    print('Installed original Yo2 gift UI and special effects, without modifying gifts.')
    return len(found)

if __name__ == '__main__':
    argv = [x for x in sys.argv[1:] if x != '--dry-run']
    if len(argv) != 2:
        raise SystemExit(
            'Usage: python3 tools/import_yo2_gift_assets.py PART1.zip PART2.zip [--dry-run]'
        )
    import_assets(Path(argv[0]), Path(argv[1]), dry_run='--dry-run' in sys.argv)

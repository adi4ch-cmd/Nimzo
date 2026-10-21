#!/usr/bin/env python3
"""Read-only APK/APKS/XAPK/ZIP media audit. Never exports executable/private data."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tempfile
import zipfile

FORMATS = {
    'png': 'Flutter image', 'webp': 'Flutter image', 'jpg': 'Flutter image',
    'jpeg': 'Flutter image', 'gif': 'Flutter animated image; decode required',
    'svg': 'flutter_svg; unsupported filters require validation',
    'svga': 'flutter_svga; runtime decode required',
    'pag': 'BLOCKED: no PAG runtime currently integrated',
    'json': 'Lottie candidate; schema and runtime validation required',
    'mp4': 'video_player or VAP; alpha metadata and audio need validation',
    'webm': 'video_player; codec validation required',
    'mp3': 'just_audio; synchronization validation required',
    'wav': 'just_audio; synchronization validation required',
    'ogg': 'just_audio; synchronization validation required',
    'm4a': 'just_audio; synchronization validation required',
    'xml': 'Android layout/resource reference; original Flutter implementation required',
}
PRIVATE = re.compile(r'(^|[/_.-])(credential|credentials|secret|secrets|token|tokens|password|firebase|google.services|keystore|session|sessions|account|accounts|userdata)([/_.-]|$)', re.I)
CATEGORIES = [
    ('room_rocket', r'rocket|diamond.blast|room.rock'),
    ('vip_svip', r'svip|(^|[/_.-])vip|membership|noble'),
    ('gifts', r'gift|present|combo'),
    ('frames', r'frame|avatar.*border'),
    ('entry_effects', r'entrance|entry|enter.effect|ride|car_'),
    ('games', r'game|jackpot|fruit|wheel|patti|poker|dice|ludo|slot'),
    ('levels_honor', r'level|medal|honor|achievement|badge'),
    ('room_tools_rewards', r'room|mic|reward|treasure|chest'),
    ('chat_bubbles', r'bubble|chat'),
    ('backgrounds', r'background|theme|(^|/)bg[_/]'),
]
MAX_ENTRY = 64 * 1024 * 1024
MAX_NESTED = 768 * 1024 * 1024
MAX_EXPANDED = 3 * 1024 * 1024 * 1024


def sha_file(stream):
    digest = hashlib.sha256()
    while chunk := stream.read(1024 * 1024):
        digest.update(chunk)
    return digest.hexdigest()


def audit_package(path):
    path = Path(path)
    result = {'filename': path.name, 'status': 'AUDITED', 'media': [], 'blocked_entries': [],
              'rights': 'owner permission asserted; per-asset scope unverified'}
    if not path.is_file():
        result.update(status='BLOCKED', reason='Package not downloaded')
        return result
    result['bytes'] = path.stat().st_size
    with path.open('rb') as source:
        result['sha256'] = sha_file(source)
    expanded = 0

    def scan(source, prefix='', depth=0):
        nonlocal expanded
        with zipfile.ZipFile(source) as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                name = entry.filename.replace('\\', '/')
                parts = PurePosixPath(name).parts
                if name.startswith('/') or '..' in parts or PRIVATE.search(name):
                    continue
                suffix = PurePosixPath(name).suffix.lower().lstrip('.')
                label = prefix + name
                if suffix in ('apk', 'apks', 'xapk', 'zip'):
                    if depth >= 3 or entry.file_size > MAX_NESTED:
                        result['blocked_entries'].append({'source': label, 'reason': 'nested archive safety limit'})
                        continue
                    expanded += entry.file_size
                    if expanded > MAX_EXPANDED:
                        raise ValueError('Expanded package safety limit')
                    with tempfile.SpooledTemporaryFile(max_size=8 * 1024 * 1024) as nested:
                        with archive.open(entry) as content:
                            while chunk := content.read(1024 * 1024):
                                nested.write(chunk)
                        nested.seek(0)
                        scan(nested, label + '!/', depth + 1)
                    continue
                if not ('assets' in parts or 'res' in parts) or suffix not in FORMATS:
                    continue
                # Arbitrary JSON can hold configuration. Only name-qualified
                # animation JSON is a media candidate; never parse credentials.
                if suffix == 'json' and not re.search(r'anim|lottie|effect', name, re.I):
                    continue
                if entry.file_size > MAX_ENTRY:
                    result['blocked_entries'].append({'source': label, 'reason': 'media size safety limit'})
                    continue
                expanded += entry.file_size
                if expanded > MAX_EXPANDED:
                    raise ValueError('Expanded package safety limit')
                with archive.open(entry) as content:
                    digest = sha_file(content)
                category = next((category for category, pattern in CATEGORIES
                                 if re.search(pattern, name, re.I)), 'unclassified_media')
                result['media'].append({
                    'source': label, 'bytes': entry.file_size, 'sha256': digest,
                    'format': suffix, 'category': category,
                    'compatibility': FORMATS[suffix],
                    'rights': result['rights'],
                    'completeness': 'candidate only; external dependencies and runtime unverified',
                    'proposed_destination': 'nimzo/assets/audited/' + category + '/',
                    'chosen_destination': None,
                })

    try:
        scan(path)
    except (zipfile.BadZipFile, RuntimeError, ValueError, OSError, NotImplementedError) as error:
        result.update(status='BLOCKED', reason=type(error).__name__)
    result['formats'] = dict(Counter(item['format'] for item in result['media']))
    result['categories'] = dict(Counter(item['category'] for item in result['media']))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages', type=Path)
    parser.add_argument('--inventory', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    inventory = json.loads(args.inventory.read_text()) if args.inventory else []
    sources = {item['title']: item for item in inventory}
    names = sorted(set(sources) | {p.name for p in args.packages.iterdir()
                                   if p.suffix.lower() in ('.apk', '.apks', '.xapk', '.zip')})
    packages = []
    duplicates = defaultdict(list)
    for name in names:
        result = audit_package(args.packages / name)
        if name in sources:
            result['drive_id'] = sources[name]['id']
            result['expected_bytes'] = int(sources[name]['size'])
            if result.get('bytes') != result['expected_bytes']:
                result.update(status='BLOCKED', reason='Download missing or size mismatch')
        for item in result['media']:
            duplicates[item['sha256']].append(name + '!/' + item['source'])
        packages.append(result)
        print(name + ': ' + result['status'] + ', ' + str(len(result['media'])) + ' media', flush=True)
    report = {'scope': 'enumerated accessible packages; APK content does not prove redistribution rights or backend functionality',
              'packages': packages,
              'duplicates': {digest: paths for digest, paths in duplicates.items() if len(paths) > 1}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2))
    summary = {'packages': [{k: v for k, v in p.items() if k not in ('media', 'blocked_entries')} for p in packages],
               'media_count': sum(len(p['media']) for p in packages),
               'duplicate_groups': len(report['duplicates']), 'scope': report['scope']}
    args.output.with_suffix('.summary.json').write_text(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()

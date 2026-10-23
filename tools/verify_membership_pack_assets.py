#!/usr/bin/env python3
"""Verify original bytes, provenance and exact category/tier membership index."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]

def verify():
    index=json.loads((ROOT/'nimzo/assets/membership/packs/provenance.json').read_text())
    assert set(index)=={f'{kind}{tier}' for kind in ['vip','svip'] for tier in range(1,11)}
    checked=0
    for pack,slots in index.items():
        kind='svip' if pack.startswith('svip') else 'vip'
        tier=int(pack.removeprefix(kind))
        for slot,row in slots.items():
            assert row['source_kind']==kind and row['source_tier']==tier,(pack,slot)
            assert row['source_archive_path'] and row['source_package'],(pack,slot)
            path=ROOT/'nimzo'/row['path']
            assert path.is_file(),path
            assert hashlib.sha256(path.read_bytes()).hexdigest()==row['source_sha256']==row['sha256'],path
            if slot in ['entrance_animation','mic_animation']:
                assert path.suffix=='.svga' and row.get('animation',{}).get('frames',0)>1,(pack,slot)
            checked+=1
        assert slots['avatar_frame'],f'{pack} original frame missing'
    print(f'PASS: {checked} original slot records across all20 tiers have exact metadata and original checksums')
    return checked

if __name__=='__main__':verify()

#!/usr/bin/env python3
from pathlib import Path
import json,hashlib,collections,sys
root=Path('nimzo/assets/willchill_premium')
if not root.exists():sys.exit('Run from NIMZO repository root after unpacking package')
data=json.loads((root/'catalog.json').read_text())
seen=set();groups=collections.Counter();kinds=collections.Counter()
for item in data['records']:
    p=Path('nimzo')/item['asset']
    assert str(p).startswith('nimzo/assets/willchill_premium/'),p
    assert p.exists(),p
    assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],p
    assert item['asset'] not in seen,item['asset'];seen.add(item['asset'])
    groups[item['group']]+=1;kinds[item['type']]+=1
assert len(seen)==261,len(seen)
assert kinds['vap']>=20,kinds
assert kinds['svga']>=10,kinds
print('VERIFIED',len(seen),'unique source assets, SHA256 all correct')
print('Remaining non-membership media types',dict(kinds),'groups',dict(groups))

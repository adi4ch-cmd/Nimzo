#!/usr/bin/env python3
"""Extract exact owner-provided archive bytes; never activates backend media."""
import argparse,hashlib,io,json,math,struct,zipfile,zlib
from pathlib import Path
from PIL import Image
from import_verified_free_gift_assets import parse_fields
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('yoho_selection',type=Path);p.add_argument('other_selection',type=Path);p.add_argument('packages',type=Path);a=p.parse_args()
selection=json.loads(a.yoho_selection.read_text())+json.loads(a.other_selection.read_text())
assert len(selection)==70
records=[];seen=set();slots=set()
for package in sorted({r['source_package'] for r in selection}):
    subset=[r for r in selection if r['source_package']==package]
    archive=(a.packages/package).read_bytes();archive_sha=hashlib.sha256(archive).hexdigest()
    with zipfile.ZipFile(io.BytesIO(archive)) as outer:
        nested={}
        for r in subset:
            assert archive_sha==(r.get('archive_sha256') or r.get('source_archive_sha256'))
            source=r.get('archive_path') or r['source'];apk,entry=source.split('!/',1)
            if apk not in nested:nested[apk]=zipfile.ZipFile(io.BytesIO(outer.read(apk)))
            data=nested[apk].read(entry);sha=hashlib.sha256(data).hexdigest()
            assert sha==(r.get('sha256') or r.get('source_sha256'))
            assert sha not in seen;seen.add(sha)
            slot=(r['kind'],r['tier'],r['role']);assert slot not in slots;slots.add(slot)
            if entry.endswith('.svga'):
                codec='svga';mime='application/x-svga';ext='.svga';kind='svga'
                d=zlib.decompressobj();raw=d.decompress(data,24*1024*1024+1);assert d.eof and not d.unused_data and len(raw)<=24*1024*1024
                params=dict(parse_fields(dict(parse_fields(raw))[2]));width,height=[struct.unpack('<f',params[k])[0] for k in [1,2]];fps,frames=[int(params[k]) for k in [3,4]]
            else:
                with Image.open(io.BytesIO(data)) as image:
                    assert getattr(image,'n_frames',1)==1;codec=image.format.lower();mime=Image.MIME[image.format];width,height=image.size;image.verify()
                kind='image';ext={'png':'.png','jpeg':'.jpg','webp':'.webp'}[codec];fps=frames=1
            assert len(data)<=4194304 and codec in ['png','webp','jpeg','svga']
            asset=f'assets/membership/remix/{sha}{ext}';target=ROOT/'nimzo'/asset;target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists():assert target.read_bytes()==data
            else:target.write_bytes(data)
            records.append(dict(id=f"membership-{r['kind']}-{r['tier']}-{r['role']}",name=f"{r['kind'].upper()} {r['tier']} {r['role']}",kind=r['kind'],tier=r['tier'],role=r['role'],asset=asset,sha256=sha,bytes=len(data),mime_type=mime,codec=codec,media_kind=kind,width=width,height=height,frames=frames,fps=fps,duration_ms=math.ceil(frames/fps*1000) if kind=='svga' else 0,source_package=package,source_package_sha256=archive_sha,source=source,drive_id=r['drive_id']))
assert slots=={(kind,tier,role) for kind in ['vip','svip'] for tier in range(1,11) for role in ['hero','badge','card']} | {('svip',tier,'hero_still') for tier in range(1,11)}
records.sort(key=lambda r:(r['kind'],r['tier'],r['role']))
(ROOT/'nimzo/assets/membership/remix/manifest.json').write_text(json.dumps({'schema':1,'source_choice':{'vip':'YoHo crests/badges and Mizah backgrounds','svip':'Falla animated crests, badges and podium backgrounds'},'activation':'STAGED: genuine Android proof required before backend approval','items':records},indent=2)+'\n')
print('Extracted70 original assets;20 complete membership tiers; no Voku selection; source SHA checked')

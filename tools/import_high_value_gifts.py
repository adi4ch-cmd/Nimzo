#!/usr/bin/env python3
"""Import diverse original SVGA/VAP gifts; never activate or change old catalog."""
import argparse,hashlib,io,json,math,uuid,zipfile
from urllib.parse import urlsplit
from gift_selection_policy import validate_selection
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('selection',type=Path);p.add_argument('packages',type=Path);p.add_argument('--allow-partial',action='store_true',help='Import a truthful shortlist; never claim the requested20 are complete');a=p.parse_args()
rows=json.loads(a.selection.read_text())['items']
validate_selection(rows,allow_partial=a.allow_partial)
records=[];seen=set()
for package in {r['source_package'] for r in rows}:
 archive=(a.packages/package).read_bytes();sha_archive=hashlib.sha256(archive).hexdigest()
 with zipfile.ZipFile(io.BytesIO(archive)) as z:
  nested={}
  for r in rows:
   if r['source_package']!=package:continue
   assert sha_archive==r['source_package_sha256']
   apk,entry=r['source'].split('!/',1)
   if apk not in nested:nested[apk]=zipfile.ZipFile(io.BytesIO(z.read(apk)))
   source_bytes=nested[apk].read(entry)
   source_url=r.get('source_url')
   if source_url:
    parsed=urlsplit(source_url)
    assert parsed.scheme=='https' and parsed.hostname and not parsed.username and not parsed.password
    assert source_url in source_bytes.decode('utf-8',errors='replace').replace('\\/','/'), 'CDN URL must be literal in pinned source APK entry'
    data=Path(r['local_path']).read_bytes()
   else:data=source_bytes
   sha=hashlib.sha256(data).hexdigest();assert sha==r['sha256'] and sha not in seen;seen.add(sha)
   kind=r['media_kind'];assert kind in ('vap','svga')
   config=r.get('vap_config',r.get('vapc'))
   if kind=='vap':assert config['info']['isVapx']==0 and not config.get('src')
   suffix='.mp4' if kind=='vap' else '.svga'
   mime='video/mp4' if kind=='vap' else 'application/x-svga'
   asset=f'assets/drive_catalog_premium/{sha}{suffix}';target=ROOT/'nimzo'/asset;target.parent.mkdir(exist_ok=True)
   if target.exists():assert target.read_bytes()==data
   else:target.write_bytes(data)
   thumb=Path(r['thumbnail_path']).read_bytes()
   with Image.open(io.BytesIO(thumb)) as image:assert image.format=='PNG';image.verify()
   th=hashlib.sha256(thumb).hexdigest();thumbnail=f'assets/drive_catalog_premium/{th}.png';(ROOT/'nimzo'/thumbnail).write_bytes(thumb)
   records.append(dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,'nimzo:gift:premium:20261023:'+sha)),name=r['name'],family=r['family'],category='gift',coin_price=r['coin_price'],asset=asset,sha256=sha,bytes=len(data),media_kind=kind,codec=kind,mime_type=mime,width=r['width'],height=r['height'],frames=r['frames'],fps=r['fps'],duration_ms=math.ceil(r['frames']/r['fps']*1000),thumbnail=thumbnail,thumbnail_sha256=th,thumbnail_bytes=len(thumb),thumbnail_mime_type='image/png',source_package=package,source_package_sha256=sha_archive,source=r['source'],drive_id=r['drive_id'],source_url=source_url,vap_config=config))
records.sort(key=lambda r:(r['coin_price'],r['name']))
(ROOT/'nimzo/assets/drive_catalog_premium/manifest.json').write_text(json.dumps({'schema':1,'requested_count':20,'selected_count':len(records),'remaining_count':20-len(records),'authorization':'Owner requested20 diverse gifts at500K/1M coins, maximum2 per semantic family; complete original SVGA/VAP effects','activation':'STAGED pending native render verification','items':records},indent=2)+'\n')
print(f'Imported{len(records)} diverse originals; {20-len(records)} of requested20 still missing. Max2 pertype. No existing gift changes or activation.')

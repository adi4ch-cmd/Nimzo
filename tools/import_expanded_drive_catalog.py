#!/usr/bin/env python3
"""Extract pinned second-batch Drive originals. No backend changes or false device proof."""
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import uuid
import zipfile
import zlib
from PIL import Image
from import_verified_free_gift_assets import parse_fields

ROOT=Path(__file__).resolve().parents[1]
selection=json.loads((ROOT/'tools/drive_catalog_expanded_selection.json').read_text())
audit={p['filename']:p for p in json.loads(Path(sys.argv[2]).read_text())['packages']}
dest=ROOT/'nimzo/assets/drive_catalog_expanded'
dest.mkdir(parents=True,exist_ok=True)
records=[]
seen=set()
for package in dict.fromkeys(r['package'] for r in selection):
    archive=(Path(sys.argv[1])/package).read_bytes()
    archive_hash=hashlib.sha256(archive).hexdigest()
    if archive_hash!=audit[package]['sha256']:raise ValueError('Archive mismatch: '+package)
    with zipfile.ZipFile(io.BytesIO(archive)) as outer:
      with zipfile.ZipFile(io.BytesIO(outer.read('base.apk'))) as inner:
        for row in (r for r in selection if r['package']==package):
          data=inner.read(row['source'].split('!/',1)[1])
          sha=hashlib.sha256(data).hexdigest()
          if sha!=row['sha256'] or sha in seen:raise ValueError('Duplicate or changed source: '+row['name'])
          seen.add(sha)
          suffix=Path(row['source']).suffix.lower()
          kind='svga' if suffix=='.svga' else 'image'
          codec='svga' if kind=='svga' else {'.webp':'webp','.png':'png','.jpg':'jpeg','.jpeg':'jpeg'}[suffix]
          mime={'svga':'application/x-svga','webp':'image/webp','png':'image/png','jpeg':'image/jpeg'}[codec]
          if kind=='svga':
            decoder=zlib.decompressobj();raw=decoder.decompress(data,24*1024*1024+1)
            if len(raw)>24*1024*1024 or not decoder.eof:raise ValueError('SVGA inflation bounds')
            params=dict(parse_fields(dict(parse_fields(raw))[2]))
            width=struct.unpack('<f',params[1])[0];height=struct.unpack('<f',params[2])[0]
            fps=int(params[3]);frames=int(params[4])
          else:
            with Image.open(io.BytesIO(data)) as image:
              width,height=image.size;codec=image.format.lower();mime=Image.MIME[image.format];image.verify()
            fps=frames=1
          slug=row['name'].lower().replace(' ','-')
          product_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'nimzo:drive:20261023:'+slug)) if row['category']=='gift' else 'nimzo-drive2-'+slug
          asset=f'assets/drive_catalog_expanded/{sha}{suffix}'
          target=ROOT/'nimzo'/asset
          if target.exists() and target.read_bytes()!=data:raise ValueError('Immutable target differs')
          target.write_bytes(data)
          records.append(dict(id=product_id,name=row['name'],category=row['category'],coin_price=row['coin_price'],asset=asset,sha256=sha,bytes=len(data),media_kind=kind,codec=codec,mime_type=mime,width=width,height=height,frames=frames,fps=fps,source_package=package,source_package_sha256=archive_hash,source=row['source'],drive_id=audit[package]['drive_id']))
manifest=dict(schema=1,authorization='Owner requested at least20 gifts and more Store items from supplied Drive APKs,2026-10-23',items=records)
(dest/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Imported',len(records),'unique originals:',sum(r['category']=='gift' for r in records),'gifts and',sum(r['category']!='gift' for r in records),'Store items. Inactive until Android proof and backend publication.')

#!/usr/bin/env python3
"""Generate additive SQL only after exact successful native Android evidence.

Proof JSON: source_commit (40 hex), device (contains Android), test_passed:true,
workflow_conclusion:"success", workflow_run (GitHub actions run URL),
test_completed_at (timezone-aware ISO8601), log_sha256 and native_log (path,
relative to the proof JSON directory if not absolute), plus records keyed by all
57 manifest IDs, each {sha256,frames,fps,distinct,visible}. The raw log must have
exactly those57 VERIFIED ... android=true lines and 'All tests passed.' (or !).
The production CLI independently reads GitHub run metadata, native job logs and
both manifests at the verified commit before writing SQL. It performs no storage
writes or database execution. Disposable SQL fixtures never invoke this check.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess
from urllib.request import urlopen
import zlib
from import_verified_free_gift_assets import parse_fields
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE_URL = 'https://kvqvlpozqokwarovwmwv.supabase.co/storage/v1/object/public/nimzo-drive-catalog/'
CATEGORIES = {'Avatar Frame','Party Theme','Rides','Chat Bubble','Live Frame','Royal Badge','ID Frame','Profile Card','Mic Wave'}
SHA = r'[0-9a-f]{64}'
REPOSITORY = 'adi4ch-cmd/Nimzo'
NATIVE_WORKFLOW = '.github/workflows/nimzo-drive-media-device-qa.yml'


def native_records(log):
    lines=re.findall(r'VERIFIED (\S+) sha256=('+SHA+r') frames=(\d+) fps=(\d+) distinct=(\d+) visible=(\d+) android=true',log)
    if len(lines)!=57 or len({v[0] for v in lines})!=57 or not re.search(r'All tests passed[.!](?:\s|$)',log):
        raise ValueError('Expected57 unique native successful render records')
    return {r[0]:dict(sha256=r[1],**dict(zip(['frames','fps','distinct','visible'],map(int,r[2:])))) for r in lines}


def github_api(path):
    """Use the configured GitHub identity without a shell or credential output."""
    result=subprocess.run(['gh','api',path],capture_output=True,check=False)
    if result.returncode:
        raise ValueError('Cannot verify GitHub evidence: '+path)
    return result.stdout


def verify_online_proof(proof, source_commit, root=ROOT, fetch_native_log=None):
    """Bind production evidence to GitHub's actual run, logs and pinned sources.

    A library caller may supply an authenticated GitHub log transport when the
    CLI's redirected log download is unavailable. The callback receives only the
    API endpoint for the job independently verified below and must return its
    actual log bytes. CLI execution always uses github_api; this changes only
    log transport, never metadata, source, timestamp or native-record checks.
    """
    match=re.fullmatch(r'https://github\.com/adi4ch-cmd/Nimzo/actions/runs/([0-9]+)',str(proof.get('workflow_run','')))
    if not match:
        raise ValueError('Native evidence must belong to '+REPOSITORY)
    run_id=match[1]
    run=json.loads(github_api(f'repos/{REPOSITORY}/actions/runs/{run_id}'))
    if (str(run.get('id'))!=run_id or run.get('head_sha')!=source_commit
            or run.get('status')!='completed' or run.get('conclusion')!='success'
            or run.get('path')!=NATIVE_WORKFLOW):
        raise ValueError('GitHub native workflow/source/conclusion mismatch')
    attempt=run.get('run_attempt')
    if type(attempt) is not int or attempt<1:
        raise ValueError('Missing GitHub run attempt')
    jobs=json.loads(github_api(f'repos/{REPOSITORY}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100'))
    matches=[j for j in jobs.get('jobs',[]) if j.get('name')=='android-render']
    if jobs.get('total_count',0)>100 or len(matches)!=1:
        raise ValueError('Expected one Android render job in the verified attempt')
    job=matches[0]
    if (job.get('status')!='completed' or job.get('conclusion')!='success'
            or job.get('head_sha')!=source_commit or str(job.get('run_id'))!=run_id
            or type(job.get('id')) is not int):
        raise ValueError('Android render job did not succeed at the pinned source')
    timestamp=datetime.fromisoformat(proof['test_completed_at'].replace('Z','+00:00'))
    started=datetime.fromisoformat(job['started_at'].replace('Z','+00:00'))
    completed=datetime.fromisoformat(job['completed_at'].replace('Z','+00:00'))
    if not started<=timestamp<=completed:
        raise ValueError('Device proof timestamp is outside the actual Android job')
    log_endpoint=f'repos/{REPOSITORY}/actions/jobs/{job["id"]}/logs'
    raw_log=(github_api if fetch_native_log is None else fetch_native_log)(log_endpoint)
    if not isinstance(raw_log,bytes):
        raise ValueError('Native log transport must return actual log bytes')
    actual_log=raw_log.decode('utf-8')
    if native_records(actual_log)!=proof['records']:
        raise ValueError('Actual GitHub native job records differ from proof')
    for folder in ['drive_catalog','drive_catalog_expanded']:
        relative=f'nimzo/assets/{folder}/manifest.json'
        url=f'https://raw.githubusercontent.com/{REPOSITORY}/{source_commit}/{relative}'
        with urlopen(url,timeout=30) as response:
            pinned=response.read()
        if hashlib.sha256(pinned).digest()!=hashlib.sha256((root/relative).read_bytes()).digest():
            raise ValueError('Local manifest differs from verified source commit: '+relative)


def check_file(root, item, thumbnail=False):
    asset = item['thumbnail' if thumbnail else 'asset']
    sha = item['thumbnail_sha256' if thumbnail else 'sha256']
    size = item['thumbnail_bytes' if thumbnail else 'bytes']
    mime = item['thumbnail_mime_type' if thumbnail else 'mime_type']
    path = (root/'nimzo'/asset).resolve()
    if not path.is_relative_to((root/'nimzo/assets').resolve()) or not re.fullmatch(SHA, sha):
        raise ValueError('Unsafe asset path or hash')
    data = path.read_bytes()
    if len(data) != size or hashlib.sha256(data).hexdigest() != sha:
        raise ValueError('Asset identity mismatch: '+asset)
    if mime.startswith('image/'):
        image = Image.open(io.BytesIO(data))
        if not thumbnail and (item['media_kind'] != 'image' or image.size != (item['width'],item['height']) or getattr(image,'n_frames',1)!=1):
            raise ValueError('Static manifest kind/dimensions/animation mismatch')
        if mime not in ['image/png','image/webp','image/jpeg']:
            raise ValueError('Unsupported bitmap MIME')
        if Image.MIME.get(image.format) != mime:
            raise ValueError('Bitmap MIME does not match bytes: '+asset)
        image.verify()
    elif mime != 'application/x-svga' or thumbnail or item['media_kind'] != 'svga' or path.suffix != '.svga':
        raise ValueError('Invalid animation media kind or MIME')
    else:
        if len(data)>32*1024*1024:raise ValueError('Compressed animation too large')
        decoder=zlib.decompressobj();raw=decoder.decompress(data,24*1024*1024+1)
        if len(raw)>24*1024*1024 or not decoder.eof or decoder.unused_data:
            raise ValueError('Animation inflation/trailing data invalid')
        fields=list(parse_fields(raw));params=dict(parse_fields(dict(fields)[2]))
        width,height=[struct.unpack('<f',params[k])[0] for k in [1,2]]
        fps,frames=[int(params[k]) for k in [3,4]]
        if not (0<width<=4096 and 0<height<=4096 and 0<fps<=60 and 0<frames<=3600):
            raise ValueError('Animation resource bounds')
        item.setdefault('width',width);item.setdefault('height',height)
        if (width,height,fps,frames)!=(item['width'],item['height'],item['fps'],item['frames']):
            raise ValueError('Animation manifest parameters differ')
        images={};pixels=0;sprite_keys=[];vectors=set()
        for field,value in fields:
            if field==3:
                entry=dict(parse_fields(value));name=entry[1].decode('utf-8')
                im=Image.open(io.BytesIO(entry[2]));pixels+=im.width*im.height;im.verify()
                if name in images:raise ValueError('Duplicate image key')
                images[name]=True
            elif field==4:
                sprite=list(parse_fields(value));key=dict(sprite).get(1,b'').decode('utf-8')
                sprite_keys.append(key)
                if key.endswith('.vector') and any(f==5 for k,b in sprite if k==2 for f,_ in parse_fields(b)):
                    vectors.add(key)
        if len(images)>128 or len(sprite_keys)>256 or pixels>32000000:
            raise ValueError('Animation image/sprite/pixel cap')
        if any(k and k not in images and k not in vectors for k in sprite_keys):
            raise ValueError('Unresolved animation raster reference')


def load_catalog(root=ROOT):
    batches = [json.loads((root/f'nimzo/assets/{folder}/manifest.json').read_text())['items']
               for folder in ['drive_catalog','drive_catalog_expanded']]
    old, items = batches
    if len(old)!=9 or len(items)!=48 or sum(v['category']=='gift' for v in items)!=20:
        raise ValueError('Expected old9 and expanded20 gifts/28 Store products')
    all_items = old + items
    if len({v['id'] for v in all_items})!=57 or len({v['sha256'] for v in all_items})!=57:
        raise ValueError('Duplicate product IDs or source media')
    for v in all_items:
        if type(v['coin_price']) is not int or v['coin_price']<=0:
            raise ValueError('Positive integer price required')
        if v['category']!='gift' and v['category'] not in CATEGORIES:
            raise ValueError('Unsupported Store category')
        if v['media_kind'] not in ['image','svga'] or (v['category']=='gift' and v['media_kind']!='svga'):
            raise ValueError('Unsupported media kind')
        if v.get('duration_days') is not None:
            raise ValueError('Expanded catalog must be lifetime')
        # Original batch predates the explicit MIME field.
        v.setdefault('mime_type', 'application/x-svga' if v['media_kind']=='svga' else None)
        v.setdefault('thumbnail_mime_type','image/png')
        check_file(root,v);check_file(root,v,True)
    return old, items


def validate_proof(proof, items, source_commit, proof_dir=Path('.')):
    if not re.fullmatch(r'[0-9a-f]{40}',source_commit) or source_commit == '0'*40 or proof.get('source_commit') != source_commit:
        raise ValueError('Exact source commit required')
    if (proof.get('test_passed') is not True or proof.get('workflow_conclusion')!='success'
            or 'android' not in str(proof.get('device','')).lower()
            or not re.fullmatch(r'https://github\.com/[^/]+/[^/]+/actions/runs/[0-9]+',str(proof.get('workflow_run','')))):
        raise ValueError('Successful actual Android workflow required')
    try:
        timestamp=datetime.fromisoformat(proof['test_completed_at'].replace('Z','+00:00'))
        if timestamp.tzinfo is None or timestamp > datetime.now(timezone.utc):
            raise ValueError('Invalid completion timestamp')
        log_path=Path(proof['native_log'])
        raw=(log_path if log_path.is_absolute() else proof_dir/log_path).read_bytes()
    except (KeyError,OSError,TypeError) as e:
        raise ValueError('Native log and timezone-aware completion timestamp required') from e
    if hashlib.sha256(raw).hexdigest()!=proof.get('log_sha256'):
        raise ValueError('Native log hash mismatch')
    log=raw.decode('utf-8')
    records=native_records(log)
    if records!=proof.get('records') or set(records)!={v['id'] for v in items}:
        raise ValueError('Proof JSON/native log/manifest ID sets differ')
    for v in items:
        r=records[v['id']]
        if r['sha256']!=v['sha256'] or r['frames']!=v['frames'] or r['fps']!=v['fps']:
            raise ValueError('Native resource metadata mismatch: '+v['id'])
        if v['media_kind']=='image':
            if (r['frames'],r['fps'],r['distinct'],r['visible'])!=(1,1,1,1):
                raise ValueError('Static media proof mismatch')
        elif r['distinct']<3 or r['visible']<=r['frames']//2 or not (r['distinct']<=r['frames'] and r['visible']<=r['frames']):
            raise ValueError('Incomplete native animation: '+v['id'])
    return proof['test_completed_at']


def q(value):
    if value is None:return 'null'
    if isinstance(value,bool):return 'true' if value else 'false'
    if isinstance(value,(int,float)):return str(value)
    return "'"+str(value).replace("'","''")+"'"


def insert(table, values):
    return 'insert into public.'+table+'('+','.join(values)+') values('+','.join(q(v) for v in values.values())+');'


def build_sql(items, source_commit, verified_at, evidence_reference):
    """Pure SQL builder. CLI must validate_proof first; fixtures label themselves."""
    gifts=[v for v in items if v['category']=='gift'];store=[v for v in items if v['category']!='gift']
    gift_ids=','.join(q(v['id']) for v in gifts);store_ids=','.join(q(v['id']) for v in store)
    rights='Owner-authorized supplied Drive APK extraction; source commit '+source_commit+'; '+evidence_reference
    result=['-- Additive expanded Drive catalog. '+evidence_reference.replace('\n',' '), '-- Source commit '+source_commit+'. No existing wallet/ownership/ledger writes.', 'begin;',
       f"do $$ begin if exists(select 1 from public.gifts where id in ({gift_ids})) or exists(select 1 from public.nimzo_cosmetic_catalog where id in ({store_ids})) then raise exception 'Drive product ID already exists; preserve existing data and review collision'; end if; end $$;"]
    for i,v in enumerate(items):
        url=BASE_URL+Path(v['asset']).name;thumb=BASE_URL+Path(v['thumbnail']).name
        media=dict(approved=True,media_kind=v['media_kind'],sha256=v['sha256'],byte_size=v['bytes'],mime_type=v['mime_type'],rights_reference=rights,verified_at=verified_at,device_verified_at=verified_at)
        if v['category']=='gift':
            result.append(insert('gifts',dict(id=v['id'],name=v['name'],category='premium',coin_price=v['coin_price'],asset_path=thumb,active=False,requires_approved_media=True,thumbnail_sha256=v['thumbnail_sha256'],thumbnail_byte_size=v['thumbnail_bytes'],thumbnail_mime_type=v['thumbnail_mime_type'],priority=50,min_vip_tier=0)))
            result.append(insert('gift_animation_media',dict(gift_id=v['id'],video_url=url,duration_ms=v['duration_ms'],sound_enabled=False,**media,aspect_ratio=v['width']/v['height'],transparent=True,source_record='Drive:'+v['drive_id']+'/'+v['source_package']+'!/'+v['source'])))
        else:
            result.append(insert('nimzo_cosmetic_catalog',dict(id=v['id'],category=v['category'],name=v['name'],variant=i%7,coin_price=v['coin_price'],active=False,duration_days=None)))
            result.append(insert('nimzo_cosmetic_media',dict(item_id=v['id'],thumbnail_url=thumb,asset_url=url,**media,thumbnail_sha256=v['thumbnail_sha256'],thumbnail_byte_size=v['thumbnail_bytes'],thumbnail_mime_type=v['thumbnail_mime_type'])))
    result.extend([f'update public.gifts set active=true where id in ({gift_ids});',f'update public.nimzo_cosmetic_catalog set active=true where id in ({store_ids});','commit;'])
    return '\n\n'.join(result)+'\n'


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--device-proof',required=True,type=Path)
    p.add_argument('--source-commit',required=True)
    p.add_argument('--output',required=True,type=Path,help='Existing empty migration file or new review SQL output; never executed')
    a=p.parse_args()
    old,items=load_catalog()
    proof=json.loads(a.device_proof.read_text())
    timestamp=validate_proof(proof,old+items,a.source_commit,a.device_proof.resolve().parent)
    verify_online_proof(proof,a.source_commit)
    if a.output.exists() and a.output.read_text().strip():
        p.error('Refusing to overwrite nonempty SQL file')
    a.output.write_text(build_sql(items,a.source_commit,timestamp,'Android native proof: '+proof['workflow_run']+'; log SHA256 '+proof['log_sha256']))
    print('Generated additive20 gift/28 Store SQL after exact57-record Android verification:',a.output)


if __name__=='__main__':main()

#!/usr/bin/env python3
"""Generate review SQL only after genuine pinned Android proof; never executes it."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
from urllib.request import urlopen

from generate_expanded_drive_migration import (
    ROOT, BASE_URL, REPOSITORY, NATIVE_WORKFLOW, SHA,
    check_file, github_api, insert, q,
)
from gift_selection_policy import validate_selection

FOLDERS = ['drive_catalog', 'drive_catalog_expanded', 'membership/remix', 'drive_catalog_premium']


def load_items(root=ROOT):
    batches = [json.loads((root / f'nimzo/assets/{folder}/manifest.json').read_text())['items']
               for folder in FOLDERS]
    if [len(batch) for batch in batches] != [9, 48, 70, 7]:
        raise ValueError('Expected 57 existing, 70 membership and 7 shortlisted originals')
    old, expanded, membership, gifts = batches
    validate_selection(gifts, allow_partial=True)
    all_items = old + expanded + membership + gifts
    if len({r['id'] for r in all_items}) != 134 or len({r['sha256'] for r in all_items}) != 134:
        raise ValueError('Duplicate product ID or original bytes')
    for row in membership + gifts:
        if row['media_kind'] == 'vap':
            data = (root / 'nimzo' / row['asset']).read_bytes()
            if (len(data) != row['bytes'] or hashlib.sha256(data).hexdigest() != row['sha256']
                    or len(data) > 8388608 or data[4:8] != b'ftyp'):
                raise ValueError('VAP original identity or size mismatch')
            config = row['vap_config']
            info = config['info']
            if (info['isVapx'] != 0 or config.get('src') or
                    (info['w'], info['h'], info['fps'], info['f']) !=
                    (row['width'], row['height'], row['fps'], row['frames'])):
                raise ValueError('VAP must be complete and self-contained')
        else:
            check_file(root, row)
        if row in gifts:
            check_file(root, row, True)
    return membership, gifts, all_items


def native_records(log, items):
    if not re.search(r'All tests passed[.!](?:\s|$)', log):
        raise ValueError('Successful native suite required')
    records = {}
    regular = re.findall(r'VERIFIED (\S+) sha256=(' + SHA +
        r') frames=(\d+) fps=(\d+) distinct=(\d+) visible=(\d+) android=true', log)
    vap = re.findall(r'VERIFIED_VAP (\S+) sha256=(' + SHA +
        r') declared=(\d+) rendered=(\d+) first=(\d+) last=(\d+) samples=(\d+) distinct=(\d+) visible=(\d+) completed=true android=true', log)
    for row in regular:
        identity, digest, *numbers = row
        if identity in records:
            raise ValueError('Duplicate native record')
        records[identity] = dict(sha256=digest, kind='raster',
            **dict(zip(['frames', 'fps', 'distinct', 'visible'], map(int, numbers))))
    for row in vap:
        identity, digest, *numbers = row
        if identity in records:
            raise ValueError('Duplicate native record')
        records[identity] = dict(sha256=digest, kind='vap',
            **dict(zip(['declared', 'rendered', 'first', 'last', 'samples', 'distinct', 'visible'], map(int, numbers))))
    if set(records) != {item['id'] for item in items}:
        raise ValueError('Native log must cover every exact manifest ID')
    for item in items:
        record = records[item['id']]
        if record['sha256'] != item['sha256']:
            raise ValueError('Native source hash mismatch')
        if item['media_kind'] == 'vap':
            frames = item['frames']
            if (record['kind'] != 'vap' or record['declared'] != frames or
                    not int(frames * .9) <= record['rendered'] <= frames or
                    record['first'] > 1 or record['last'] != frames - 1 or
                    record['samples'] < 3 or record['distinct'] < 3 or
                    record['distinct'] > record['samples'] or
                    not record['samples'] // 2 < record['visible'] <= record['samples']):
                raise ValueError('Incomplete native VAP render/completion proof')
        else:
            if (record['kind'] != 'raster' or record['frames'] != item['frames'] or
                    record['fps'] != item['fps']):
                raise ValueError('Native frame parameters differ')
            if item['media_kind'] == 'image':
                if (record['frames'], record['fps'], record['distinct'], record['visible']) != (1, 1, 1, 1):
                    raise ValueError('Invalid static image proof')
            elif not (3 <= record['distinct'] <= record['frames'] and
                      record['frames'] // 2 < record['visible'] <= record['frames']):
                raise ValueError('Incomplete every-frame animation proof')
    return records


def verify_proof(proof, source_commit, items, proof_dir, root=ROOT, fetch_native_log=None):
    if (not re.fullmatch(r'[a-f0-9]{40}', source_commit) or source_commit == '0' * 40 or
            proof.get('source_commit') != source_commit or proof.get('test_passed') is not True):
        raise ValueError('Exact successful source proof required')
    match = re.fullmatch(r'https://github\.com/adi4ch-cmd/Nimzo/actions/runs/([0-9]+)', str(proof.get('workflow_run', '')))
    if not match:
        raise ValueError('Authorized repository native workflow required')
    log_path = Path(proof['native_log'])
    raw = (log_path if log_path.is_absolute() else proof_dir / log_path).read_bytes()
    if hashlib.sha256(raw).hexdigest() != proof['log_sha256']:
        raise ValueError('Saved native log hash mismatch')
    records = native_records(raw.decode('utf-8'), items)
    if records != proof['records']:
        raise ValueError('Proof records differ from saved log')
    run_id = match[1]
    run = json.loads(github_api(f'repos/{REPOSITORY}/actions/runs/{run_id}'))
    if (str(run.get('id')) != run_id or run.get('head_sha') != source_commit or
            run.get('status') != 'completed' or run.get('conclusion') != 'success' or
            run.get('path') != NATIVE_WORKFLOW):
        raise ValueError('Actual GitHub native workflow did not succeed at this source')
    attempt = run.get('run_attempt')
    if type(attempt) is not int or attempt < 1:
        raise ValueError('Missing run attempt')
    jobs = json.loads(github_api(f'repos/{REPOSITORY}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100'))
    matches = [job for job in jobs.get('jobs', []) if job.get('name') == 'android-render']
    if jobs.get('total_count', 0) > 100 or len(matches) != 1:
        raise ValueError('Expected exactly one native render job')
    job = matches[0]
    if (job.get('head_sha') != source_commit or str(job.get('run_id')) != run_id or
            job.get('status') != 'completed' or job.get('conclusion') != 'success'):
        raise ValueError('Actual native job did not succeed')
    timestamp = datetime.fromisoformat(proof['test_completed_at'].replace('Z', '+00:00'))
    started = datetime.fromisoformat(job['started_at'].replace('Z', '+00:00'))
    completed = datetime.fromisoformat(job['completed_at'].replace('Z', '+00:00'))
    if timestamp.tzinfo is None or not started <= timestamp <= completed or timestamp > datetime.now(timezone.utc):
        raise ValueError('Completion time outside actual native job')
    endpoint = f'repos/{REPOSITORY}/actions/jobs/{job["id"]}/logs'
    actual = (github_api if fetch_native_log is None else fetch_native_log)(endpoint)
    if not isinstance(actual, bytes) or native_records(actual.decode('utf-8'), items) != records:
        raise ValueError('Actual native job log differs')
    for folder in FOLDERS:
        relative = f'nimzo/assets/{folder}/manifest.json'
        with urlopen(f'https://raw.githubusercontent.com/{REPOSITORY}/{source_commit}/{relative}', timeout=30) as response:
            pinned = response.read()
        if pinned != (root / relative).read_bytes():
            raise ValueError('Local manifest differs from native source')
    return proof['test_completed_at']


def descriptor(row):
    return dict(url=BASE_URL + Path(row['asset']).name, sha256=row['sha256'],
                bytes=row['bytes'], format=row['codec'])


def build_sql(membership, gifts, source_commit, verified_at, evidence):
    """Pure builder for isolated fixtures; production CLI requires verify_proof."""
    gift_ids = ','.join(q(row['id']) for row in gifts)
    result = ['-- ' + evidence.replace('\n', ' '),
        '-- Seven selected gifts; thirteen requested gifts still missing. No existing user-data updates.',
        'begin;', f"do $$ begin if exists(select 1 from public.nimzo_membership_presentations) or exists(select 1 from public.gifts where id in ({gift_ids})) then raise exception 'Refresh collision: preserve existing data'; end if; end $$;"]
    rights = 'Owner-authorized supplied APK extraction; source ' + source_commit + '; ' + evidence
    for row in gifts:
        result.append(insert('gifts', dict(id=row['id'], name=row['name'], category='premium', coin_price=row['coin_price'],
            asset_path=BASE_URL+Path(row['thumbnail']).name, active=False, requires_approved_media=True,
            thumbnail_sha256=row['thumbnail_sha256'], thumbnail_byte_size=row['thumbnail_bytes'],
            thumbnail_mime_type=row['thumbnail_mime_type'], priority=60, min_vip_tier=0)))
        source = 'Drive:'+row['drive_id']+'/'+row['source_package']+'!/'+row['source']
        if row.get('source_url'):
            source += '; literal CDN '+row['source_url']
        result.append(insert('gift_animation_media', dict(gift_id=row['id'], video_url=BASE_URL+Path(row['asset']).name,
            duration_ms=row['duration_ms'], sound_enabled=False, approved=True, media_kind=row['media_kind'],
            sha256=row['sha256'], byte_size=row['bytes'], mime_type=row['mime_type'], rights_reference=rights,
            verified_at=verified_at, device_verified_at=verified_at, aspect_ratio=row['width']/row['height'],
            transparent=True, source_record=source)))
    for kind in ['vip', 'svip']:
        for tier in range(1, 11):
            rows = {row['role']: row for row in membership if row['kind'] == kind and row['tier'] == tier}
            hero = descriptor(rows.get('hero_still', rows['hero']))
            if rows['hero']['codec'] == 'svga':
                hero['animation'] = descriptor(rows['hero'])
            provenance = '; '.join(row['source_package']+'!/'+row['source']+' SHA256 '+row['sha256'] for row in rows.values())
            result.append(insert('nimzo_membership_presentations', dict(kind=kind, tier=tier, title=kind.upper()+' '+str(tier),
                hero=json.dumps(hero), badge=json.dumps(descriptor(rows['badge'])), card=json.dumps(descriptor(rows['card'])),
                benefit_keys='{badge,room_entry,'+('daily_reward' if kind=='vip' else 'weekly_reward')+'}',
                active=True, approved=True, source_record=provenance, rights_record=rights, device_proof_record=evidence)))
    result.extend([f'update public.gifts set active=true where id in ({gift_ids});', 'commit;'])
    return '\n\n'.join(result)+'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-proof', type=Path, required=True)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    membership, gifts, items = load_items()
    proof = json.loads(args.device_proof.read_text())
    verified_at = verify_proof(proof, args.source_commit, items, args.device_proof.resolve().parent)
    if args.output.exists() and args.output.read_text().strip():
        parser.error('Refusing to overwrite nonempty review SQL')
    evidence = 'Android native proof: '+proof['workflow_run']+'; log SHA256 '+proof['log_sha256']
    args.output.write_text(build_sql(membership, gifts, args.source_commit, verified_at, evidence))
    print('Generated review SQL for20 membership presentations and7 diverse gifts;13 gifts still missing')


if __name__ == '__main__':
    main()

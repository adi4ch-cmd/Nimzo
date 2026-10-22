#!/usr/bin/env python3
"""Fail closed before ANY package build until the owner's combined v3 task passes."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = frozenset({'gifts','memberships','store_backpack','voice_rooms_15',
    'games','progression','premium_ui','room_rocket','dynamic_audit',
    'dynamic_models','dynamic_sync','financial_security','vivox_sdk','source_tests'})


def app_source_digest(root):
    digest = hashlib.sha256()
    paths = []
    for name in ('nimzo/lib','nimzo/native','nimzo/assets','supabase/migrations'):
        folder = root / name
        if folder.is_dir():
            paths.extend(path for path in folder.rglob('*') if path.is_file())
    paths.extend(root / name for name in ('nimzo/pubspec.yaml','nimzo/pubspec.lock','nimzo/FEATURES.lock.json'))
    for path in sorted(paths):
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode() + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


QA_REQUIRED = frozenset({'dynamic_audit','dynamic_models','dynamic_sync',
    'financial_security','source_tests','gifts','memberships','store_backpack',
    'room_rocket','progression'})


def validate(record, source_digest, *, dynamic_qa=False):
    errors = []
    if record.get('schema_version') != 1: errors.append('Unknown acceptance schema')
    if dynamic_qa:
        if record.get('qa_build_authorized') is not True: errors.append('Dynamic QA build authorization is HOLD')
        if record.get('qa_open_blockers') != []: errors.append('Dynamic QA acceptance blockers remain open')
        if record.get('voice_enabled') is not True and record.get('voice_status') != 'OWNER_DEFERRED':
            errors.append('Voice omission requires the recorded owner deferral')
    else:
        if record.get('build_authorized') is not True: errors.append('Combined task build authorization is HOLD')
        if record.get('voice_enabled') is not True: errors.append('Final build must include verified Vivox voice')
        if record.get('open_blockers') != []: errors.append('Required acceptance blockers remain open')
    if record.get('app_source_sha256') != source_digest: errors.append('Acceptance is missing or stale for this application source')
    checks = record.get('qa_checks' if dynamic_qa else 'checks', {})
    if not isinstance(checks, dict): checks = {}
    for name in sorted(QA_REQUIRED if dynamic_qa else REQUIRED):
        check = checks.get(name)
        if not isinstance(check, dict) or check.get('status') != 'PASS':
            errors.append(f'{name}: acceptance has not passed')
        elif not isinstance(check.get('evidence'), list) or not check['evidence'] or not all(isinstance(v,str) and v.strip() for v in check['evidence']):
            errors.append(f'{name}: verified evidence is missing')
    if errors: raise ValueError('\n'.join(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--voice-disabled-workflow', action='store_true')
    parser.add_argument('--dynamic-qa', action='store_true',
        help='Owner-authorized TEST APK after dynamic source/backend acceptance')
    args = parser.parse_args()
    try:
        if args.voice_disabled_workflow:
            raise ValueError('Legacy voice-disabled builds are retired by the v3 owner instruction')
        record = json.loads((ROOT/'release/acceptance.json').read_text())
        validate(record, app_source_digest(ROOT), dynamic_qa=args.dynamic_qa)
    except (OSError, ValueError, TypeError) as error:
        print('APK BUILD HELD — no package was built.\n'+str(error), file=sys.stderr)
        return 1
    print('Dynamic QA acceptance PASS; TEST APK only, voice as recorded' if args.dynamic_qa
          else 'Combined v3 pre-build acceptance PASS; final voice-enabled build may proceed')
    return 0


if __name__ == '__main__':
    sys.exit(main())

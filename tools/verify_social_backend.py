"""Test social migrations on a disposable clone of schema-only metadata.

python3 tools/verify_social_backend.py --snapshot /tmp/schema.json
No production connection or real user data is used.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import time
import uuid

from verify_backend_contracts import schema_sql

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--snapshot', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
container = 'nimzo-social-' + uuid.uuid4().hex[:10]
subprocess.run(['docker', 'run', '-d', '--name', container, '-e',
                'POSTGRES_HOST_AUTH_METHOD=trust', 'postgres:17-alpine'], check=True)
try:
    for _ in range(80):
        if subprocess.run(['docker', 'exec', container, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        time.sleep(.25)
    else:
        raise RuntimeError('Disposable database did not start')
    command = ['docker', 'exec', '-i', container, 'psql', '-X', '-q', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1']
    def run(sql):
        result = subprocess.run(command, input=sql, text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout
    run(schema_sql(json.loads(args.snapshot.read_text())))
    run((root / 'supabase/tests/fixtures/social_baseline.sql').read_text())
    run((root / 'supabase/migrations/20261018035405_family_and_moment_media.sql').read_text())
    run((root / 'supabase/tests/family_and_moment_media.sql').read_text())
    run((root / 'supabase/migrations/20261018082326_conversation_history.sql').read_text())
    run((root / 'supabase/tests/conversation_history.sql').read_text())
    run((root / 'supabase/migrations/20261018082329_social_notifications.sql').read_text())
    run((root / 'supabase/tests/social_notifications.sql').read_text())
    run((root / 'supabase/migrations/20261018082335_account_presence.sql').read_text())
    run((root / 'supabase/tests/account_presence.sql').read_text())
    run((root / 'supabase/tests/disabled_rewards.sql').read_text())
    query = """set role authenticated;
    select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000103',false);
    select public.create_family('Concurrent family','','concurrent_family_key');"""
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(run, [query, query]))
    if sum('"already_processed": false' in row for row in responses) != 1:
        raise AssertionError('Concurrent requests did not create exactly once')
    run("""do $$begin
      if (select coins from wallets where user_id='00000000-0000-4000-8000-000000000103')<>2000000
       or (select count(*) from ledger where user_id='00000000-0000-4000-8000-000000000103' and kind='family_creation')<>1 then
       raise exception 'Concurrent family charge was not exactly once'; end if;
    end$$;""")
    print('PASS: full schema migrations, social authorization, 1M creation/free join, replay/concurrent debit, media, history, notifications, multi-session presence and disabled rewards')
finally:
    subprocess.run(['docker', 'rm', '-f', container], check=False, stdout=subprocess.DEVNULL)

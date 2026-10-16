"""Validate Diamond Blast only inside a disposable PG17 metadata clone."""
import argparse
import json
import subprocess
import time
import uuid
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from verify_backend_contracts import schema_sql

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--snapshot', required=True, type=Path)
parser.add_argument('--without-migration', action='store_true', help='Check expected missing-feature failure')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
container = 'nimzo-diamond-' + uuid.uuid4().hex[:10]
subprocess.run(['docker','run','-d','--name',container,'-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine'], check=True, stdout=subprocess.DEVNULL)
try:
    for _ in range(40):
        if subprocess.run(['docker','exec',container,'pg_isready','-h','127.0.0.1','-U','postgres'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        time.sleep(.25)
    else:
        raise RuntimeError('PostgreSQL did not start')
    cmd = ['docker','exec','-i',container,'psql','-h','127.0.0.1','-X','-q','-U','postgres','-v','ON_ERROR_STOP=1']
    def query(sql):
        result = subprocess.run(cmd, input=sql, text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout
    query(schema_sql(json.loads(args.snapshot.read_text())))
    query('create publication supabase_realtime;')
    if not args.without_migration:
        query((root/'supabase/migrations/20261008231759_room_diamond_blast.sql').read_text())
    if not args.without_migration:
        query((root/'supabase/tests/backend_targeted_repair.sql').read_text())
        print('PASS existing backend settlement/game/permission contract regression suite')
    sql = (root/'supabase/tests/room_diamond_blast.sql').read_text()
    if not sql.rstrip().endswith('rollback;'):
        raise RuntimeError('Fixture SQL must default to rollback')
    query(sql.rstrip()[:-len('rollback;')] + 'commit;')
    print('PASS Diamond Blast status, boundaries, historical baseline, multi-stage, rollback and room RLS')
    # Tests leave disposable fixtures committed so separate sessions can race.
    def settle(amount):
        return query(f"begin; insert into gift_events(room_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000803',1,{amount}); select pg_sleep(0.1); commit;")
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(settle, [3000000, 3000000]))
    query("do $$ begin if (select total_coins from nimzo_private.room_diamond_cycles where room_id='00000000-0000-4000-8000-000000000803')<>6000000 or (select count(*) from room_diamond_blast_events where room_id='00000000-0000-4000-8000-000000000803')<>1 then raise exception 'concurrent settlement lost or duplicated'; end if; end $$;")
    print('PASS concurrent settlements: one stage event and exact room total')

finally:
    subprocess.run(['docker','rm','-f',container], stdout=subprocess.DEVNULL, check=False)

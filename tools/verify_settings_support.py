"""Run settings/support migration against a disposable PostgreSQL 17 schema clone."""
import argparse
import json
import subprocess
import time
import uuid
from pathlib import Path
from verify_backend_contracts import schema_sql

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--snapshot', required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
container = 'nimzo-settings-' + uuid.uuid4().hex[:10]
subprocess.run(['docker','run','-d','--name',container,'-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine'], check=True, stdout=subprocess.DEVNULL)
try:
    for _ in range(40):
        if subprocess.run(['docker','exec',container,'pg_isready','-U','postgres'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        time.sleep(.25)
    else:
        raise RuntimeError('PostgreSQL did not start')
    cmd = ['docker','exec','-i',container,'psql','-X','-q','-U','postgres','-v','ON_ERROR_STOP=1']
    subprocess.run(cmd,input=schema_sql(json.loads(args.snapshot.read_text())),text=True,check=True)
    subprocess.run(cmd,input=(root/'supabase/migrations/20261008165336_settings_support_requests.sql').read_text(),text=True,check=True)
    subprocess.run(cmd,input=(root/'supabase/tests/settings_support_requests.sql').read_text(),text=True,check=True)
finally:
    subprocess.run(['docker','rm','-f',container],stdout=subprocess.DEVNULL,check=False)

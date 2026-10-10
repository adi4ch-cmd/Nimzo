"""Replay a schema-only metadata snapshot in disposable PostgreSQL; never connects to Supabase.

Usage: python3 tools/verify_backend_contracts.py --snapshot /tmp/schema.json
       [--migration supabase/migrations/repair.sql]
The input must be the read-only schema_snapshot JSON documented in the backend report.
No production rows, credentials, network ports or game calls are used.
"""
import argparse
import json
import subprocess
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def ident(value):
    return '"' + value.replace('"', '""') + '"'


def schema_sql(snapshot):
    parts = ["create role anon; create role authenticated; create role service_role bypassrls;",
             "create schema auth; create schema extensions; create schema nimzo_private;",
             "create extension pgcrypto with schema extensions;",
             "create table auth.users(id uuid primary key, email text);",
             "create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;",
             "create function auth.role() returns text language sql stable as $$ select current_setting('role',true) $$;",
             "grant usage on schema public,auth,nimzo_private,extensions to anon,authenticated,service_role;",
             "set check_function_bodies=false;"]
    for table in snapshot['tables']:
        columns = []
        for col in table['columns']:
            declaration = ident(col['name']) + ' ' + col['type']
            if col['identity']:
                declaration += ' generated ' + ('always' if col['identity'] == 'a' else 'by default') + ' as identity'
            elif col['default']:
                declaration += ' default ' + col['default']
            if col['not_null']:
                declaration += ' not null'
            columns.append(declaration)
        parts.append('create table public.' + ident(table['name']) + '(' + ','.join(columns) + ');')
    foreign_keys = []
    for table in snapshot['tables']:
        for constraint in table['constraints'] or []:
            statement = 'alter table public.' + ident(table['name']) + ' add constraint ' + ident(constraint['name']) + ' ' + constraint['definition'] + ';'
            (foreign_keys if constraint['definition'].startswith('FOREIGN KEY') else parts).append(statement)
        if table['rls']:
            parts.append('alter table public.' + ident(table['name']) + ' enable row level security;')
    parts.extend(foreign_keys)
    parts.extend(index + ';' for index in snapshot['indexes'] or [])
    parts.extend(fn['definition'].rstrip().rstrip(';') + ';' for fn in snapshot['functions'])
    for view in snapshot['views'] or []:
        options = ' with (' + ','.join(view['options']) + ')' if view['options'] else ''
        parts.append('create view public.' + ident(view['name']) + options + ' as ' + view['definition'])
    parts.extend(trigger + ';' for trigger in snapshot['triggers'] or [])
    for policy in snapshot['policies']:
        statement = 'create policy ' + ident(policy['name']) + ' on public.' + ident(policy['table'])
        statement += ' for ' + policy['cmd'] + ' to ' + ','.join(ident(role) for role in policy['roles'])
        if policy['qual']:
            statement += ' using (' + policy['qual'] + ')'
        if policy['check']:
            statement += ' with check (' + policy['check'] + ')'
        parts.append(statement + ';')
    for grant in snapshot['column_grants']:
        parts.append('grant ' + grant['privilege'] + '(' + ident(grant['column']) + ') on public.' + ident(grant['table']) + ' to ' + ident(grant['role']) + ';')
    for fn in snapshot['functions']:
        signature = ident(fn['schema']) + '.' + ident(fn['name']) + '(' + fn['identity'] + ')'
        parts.append('revoke all on function ' + signature + ' from public,anon,authenticated,service_role;')
        for role in ['anon', 'authenticated', 'service_role']:
            if fn[role]:
                parts.append('grant execute on function ' + signature + ' to ' + role + ';')
    return '\n'.join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot', required=True, type=Path)
    parser.add_argument('--migration', type=Path)
    parser.add_argument('--concurrent', action='store_true',
                        help='Exercise two-session retries against an already repaired snapshot')
    args = parser.parse_args()
    snapshot = json.loads(args.snapshot.read_text())
    container = 'nimzo-contract-' + uuid.uuid4().hex[:10]
    subprocess.run(['docker', 'run', '-d', '--name', container, '-e', 'POSTGRES_HOST_AUTH_METHOD=trust',
                    'postgres:17-alpine'], check=True, stdout=subprocess.DEVNULL)
    try:
        import time
        for _ in range(40):
            if subprocess.run(['docker', 'exec', container, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError('Isolated PostgreSQL did not become ready')
        command = ['docker', 'exec', '-i', container, 'psql', '-X', '-q', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1']
        subprocess.run(command, input=schema_sql(snapshot), text=True, check=True)
        if args.migration:
            subprocess.run(command, input=args.migration.read_text(), text=True, check=True)
        test = Path(__file__).resolve().parents[1] / 'supabase/tests/backend_targeted_repair.sql'
        # Commit fixtures ONLY inside this disposable container for two-session races.
        sql = test.read_text().rstrip()
        if not sql.endswith('rollback;'):
            raise RuntimeError('Targeted fixture transaction must end in rollback')
        subprocess.run(command, input=sql[:-len('rollback;')] + 'commit;', text=True, check=True)
        if args.migration or args.concurrent:
            verify_concurrent_replays(command)
    finally:
        subprocess.run(['docker', 'rm', '-f', container], check=False, stdout=subprocess.DEVNULL)


def verify_concurrent_replays(command):
    sender = '00000000-0000-4000-8000-000000000102'
    receiver = '00000000-0000-4000-8000-000000000103'
    gift = '00000000-0000-4000-8000-000000000301'

    def query(sql, check=True):
        return subprocess.run(command + ['-t', '-A'], input=sql, text=True,
                              capture_output=True, check=check)

    room = query("select id from rooms where owner_id='00000000-0000-4000-8000-000000000101';").stdout.strip()
    for function, target, kind in [('send_gift', room, 'gift_sent'),
                                   ('send_moment_gift', '00000000-0000-4000-8000-000000000401', 'moment_gift_sent')]:
        for changed_payload in [False, True]:
            key = 'race-' + uuid.uuid4().hex
            before = int(query(f"select coins from wallets where user_id='{sender}';").stdout.strip())

            def send(quantity):
                # Both transactions begin before settlement; the winning one keeps its lock
                # briefly so the other exercises the retry path after waiting.
                return query(f"begin; set local request.jwt.claim.sub='{sender}'; "
                             f"set local role authenticated; select {function}('{target}','{receiver}',"
                             f"'{gift}',{quantity},'{key}'); select pg_sleep(0.2); commit;", check=False)

            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(send, quantity) for quantity in (1, 2 if changed_payload else 1)]
                results = [future.result() for future in futures]
            successful = [result for result in results if result.returncode == 0]
            if changed_payload:
                assert len(successful) == 1, 'Changed concurrent payload was accepted'
                failed = next(result for result in results if result.returncode != 0)
                assert 'idempotency payload mismatch' in failed.stderr, failed.stderr
            else:
                assert len(successful) == 2, [result.stderr for result in results]
                assert sum('"status": "replayed"' in result.stdout for result in results) == 1
            ledger = query(f"select coin_delta from ledger where user_id='{sender}' and kind='{kind}' and idempotency_key='{key}:sender';").stdout.strip().splitlines()
            assert len(ledger) == 1, 'Retry produced more than one ledger settlement'
            after = int(query(f"select coins from wallets where user_id='{sender}';").stdout.strip())
            assert before - after == abs(int(ledger[0])), 'Wallet differs from single settlement'
    print('PASS concurrent room/Moment identical and changed-payload retries settle once')


if __name__ == '__main__':
    main()

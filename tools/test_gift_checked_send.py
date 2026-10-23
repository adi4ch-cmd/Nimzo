#!/usr/bin/env python3
"""Run checked gift RPCs against a NEW disposable Docker PostgreSQL database.

No production connection, credentials, application build or Flutter invocation.
Original settlement functions are extracted verbatim from the audited migration.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import concurrent.futures
import json
import threading
import time

ROOT = Path(__file__).resolve().parent.parent


def command(container: str, database: str, sql: str) -> str:
    process = subprocess.run(
        ['docker', 'exec', '-i', container, 'psql', '-X', '-U', 'postgres',
         '-d', database, '-v', 'ON_ERROR_STOP=1', '-At'],
        input=sql, text=True, capture_output=True,
    )
    if process.returncode:
        raise RuntimeError(process.stderr + process.stdout)
    return process.stdout


def original_functions() -> str:
    text = (ROOT / 'supabase/migrations/20261021010526_remove_vip_svip_fields_and_gates_20261021.sql').read_text()
    result = []
    for name in ['public.send_gift', 'public.send_moment_gift', 'nimzo_private.send_profile_gift']:
        start = text.index('CREATE OR REPLACE FUNCTION ' + name + '(')
        end = text.index('end $function$;', start) + len('end $function$;')
        result.append(text[start:end])
    source = (ROOT / 'supabase/migrations/20261006231925_profile_collections_and_couple_requests.sql').read_text()
    start = source.index('create function public.send_profile_gift(')
    end = source.index('$$;', start) + len('$$;')
    result.append(source[start:end])
    return '\n'.join(result)


def concurrency_checks(container: str, database: str) -> None:
    # Commit only fictional rows in this isolated database to permit independent
    # sessions. The normal behavioral test above rolls back all its fixture rows.
    source = (ROOT / 'supabase/tests/gift_checked_send.sql').read_text()
    seed = source[source.index('insert into public.profiles'):source.index('-- No unauthenticated')]
    command(container, database, seed)
    sender = "select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);"
    room_args = "'10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1"
    profile_args = "'00000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',1"

    def parallel(statements: list[str]) -> list[str]:
        barrier = threading.Barrier(len(statements))

        def run(statement: str) -> str:
            barrier.wait(timeout=10)
            try:
                return command(container, database, 'begin;' + sender + statement + ';commit;')
            except RuntimeError as error:
                return 'ERROR:' + str(error)

        with concurrent.futures.ThreadPoolExecutor(max_workers=len(statements)) as pool:
            return list(pool.map(run, statements))

    def counts() -> dict:
        result = command(container, database, """
          select jsonb_build_object(
            'coins',(select coins from wallets where user_id='00000000-0000-0000-0000-000000000001'),
            'diamonds',(select diamonds from wallets where user_id='00000000-0000-0000-0000-000000000002'),
            'events',(select count(*) from gift_events),
            'sent',(select count(*) from ledger where user_id='00000000-0000-0000-0000-000000000001' and kind in ('gift_sent','profile_gift_sent'))
          );
        """)
        return json.loads(result.strip())

    duplicates = parallel([
        f"select public.send_gift_checked({room_args},'parallel',100)",
        f"select public.send_gift_checked({room_args},'parallel',100)",
    ])
    assert sum('"status": "ok"' in result for result in duplicates) == 1, duplicates
    assert sum('"status": "replayed"' in result for result in duplicates) == 1, duplicates
    assert counts() == {'coins': 9900, 'diamonds': 45, 'events': 1, 'sent': 1}, counts()

    legacy_retry = parallel([
        f"select public.send_gift_checked({room_args},'parallel-legacy',100)",
        f"select public.send_gift({room_args},'parallel-legacy')",
    ])
    assert sum('"status": "ok"' in result for result in legacy_retry) == 1, legacy_retry
    assert sum('"status": "replayed"' in result for result in legacy_retry) == 1, legacy_retry
    assert counts() == {'coins': 9800, 'diamonds': 90, 'events': 2, 'sent': 2}, counts()

    cross_scope = parallel([
        f"select public.send_gift_checked({room_args},'parallel-scope',100)",
        f"select public.send_profile_gift_checked({profile_args},'parallel-scope',100)",
    ])
    assert sum('"status": "ok"' in result for result in cross_scope) == 1, cross_scope
    assert sum('idempotency payload mismatch' in result for result in cross_scope) == 1, cross_scope
    assert counts() == {'coins': 9700, 'diamonds': 135, 'events': 3, 'sent': 3}, counts()

    # Hold a successful checked transaction open. Observe PgSleep after its
    # settlement, then prove an UPDATE of the very same gift cannot race it.
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        holding = pool.submit(command, container, database,
            "set application_name='gift_checked_lock_probe';begin;" + sender +
            f"select public.send_gift_checked({room_args},'catalog-lock',100);" +
            "select pg_sleep(2);commit;")
        for _ in range(30):
            active = command(container, database,
                "select count(*) from pg_stat_activity where application_name='gift_checked_lock_probe' and wait_event='PgSleep';")
            if active.strip() == '1':
                break
            time.sleep(.03)
        else:
            raise AssertionError('Did not observe held settlement transaction')
        try:
            command(container, database,
                "set lock_timeout='100ms';update gifts set coin_price=200 where id='30000000-0000-0000-0000-000000000001';")
        except RuntimeError as error:
            assert 'lock timeout' in str(error), error
        else:
            raise AssertionError('Catalog price UPDATE raced held settlement')
        assert '"status": "ok"' in holding.result()
    command(container, database,
        "update gifts set coin_price=200 where id='30000000-0000-0000-0000-000000000001';")
    stale = parallel([f"select public.send_gift_checked({room_args},'post-update',100)"])
    assert 'gift price changed' in stale[0], stale
    assert counts() == {'coins': 9600, 'diamonds': 180, 'events': 4, 'sent': 4}, counts()
    print('PASS: concurrent duplicate/legacy/cross-scope retries; exact single settlement; catalog row lock; stale post-update rejection')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='nimzo-postgres-test')
    parser.add_argument('--database', default='gift_checked_v3')
    args = parser.parse_args()
    if not re.fullmatch(r'gift_checked_[a-z0-9_]+', args.database):
        parser.error('database must be a new disposable gift_checked_* database')
    # No DROP/reset: fail instead of overwriting any pre-existing database.
    command(args.container, 'postgres', f'create database {args.database};')
    command(args.container, args.database,
            (ROOT / 'supabase/tests/fixtures/gift_checked_send.sql').read_text())
    command(args.container, args.database, original_functions())
    for migration in [
        '20261021070000_guard_new_paid_gift_media.sql',
        '20261021120000_dynamic_verified_media_publications.sql',
        '20261021144829_gift_checked_send_expected_price.sql',
        '20261022115352_dynamic_gift_availability_and_sound.sql',
    ]:
        command(args.container, args.database,
                (ROOT / 'supabase/migrations' / migration).read_text())
    print(command(args.container, args.database,
                  (ROOT / 'supabase/tests/gift_checked_send.sql').read_text()))
    print(command(args.container,args.database,(ROOT/'supabase/tests/gift_availability.sql').read_text()))
    concurrency_checks(args.container, args.database)
    print(f'PASS: disposable SQL assertions on {args.container}/{args.database}')


if __name__ == '__main__':
    main()

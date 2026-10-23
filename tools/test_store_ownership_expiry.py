#!/usr/bin/env python3
"""Exercise Store expiry in a NEW disposable Docker Postgres DB; never live."""
from __future__ import annotations
import argparse
import concurrent.futures
import json
from pathlib import Path
import re
import threading
import time
from test_gift_checked_send import command

ROOT = Path(__file__).resolve().parent.parent
USER = '00000000-0000-0000-0000-000000000002'


def concurrency_checks(container: str, database: str) -> None:
    command(container, database, f"""
      insert into auth.users values('{USER}');
      insert into profiles(id) values('{USER}');
      insert into wallets(user_id,coins) values('{USER}',1000);
      insert into nimzo_cosmetic_catalog(id,category,name,variant,coin_price,duration_days)
        values('fixture-concurrent','Avatar Frame','Concurrent frame',0,100,1);
      insert into nimzo_cosmetic_media(item_id,asset_url,media_kind,approved,
        sha256,byte_size,mime_type,rights_reference,verified_at,device_verified_at)
      values('fixture-concurrent','https://fixture.example/'||repeat('a',64)||'.png',
        'image',true,repeat('a',64),8,'image/png','Fictional concurrency fixture',now(),now());
    """)
    setting = f"select set_config('request.jwt.claim.sub','{USER}',true);"

    def parallel(keys: list[str]) -> list[dict]:
        barrier = threading.Barrier(len(keys))
        def run(key: str) -> dict:
            barrier.wait(timeout=10)
            output = command(container, database, 'begin;' + setting +
                "set local role authenticated;select nimzo_store_purchase(" +
                f"'fixture-concurrent',100,'{key}');commit;")
            return next(json.loads(line) for line in output.splitlines() if line.startswith('{'))
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(keys)) as pool:
            return list(pool.map(run, keys))

    def summary() -> dict:
        result = command(container, database, f"""
          select jsonb_build_object('coins',(select coins from wallets where user_id='{USER}'),
          'receipts',(select count(*) from ledger where user_id='{USER}'),
          'owned',(select count(*) from nimzo_cosmetic_ownership where user_id='{USER}'));
        """)
        return json.loads(result.strip())

    duplicate = parallel(['a' * 32, 'a' * 32])
    assert sorted(result['status'] for result in duplicate) == ['purchased', 'replayed'], duplicate
    assert summary() == {'coins': 900, 'receipts': 1, 'owned': 1}, summary()
    command(container, database, f"update nimzo_cosmetic_ownership set expires_at=now()-interval '1 second' where user_id='{USER}';")
    renewals = parallel(['b' * 32, 'c' * 32])
    assert sorted(result['status'] for result in renewals) == ['already_owned', 'purchased'], renewals
    assert summary() == {'coins': 800, 'receipts': 2, 'owned': 1}, summary()

    # A successful purchase retains catalog row locks through its transaction:
    # an owner changing duration cannot race an already confirmed settlement.
    command(container, database, f"update nimzo_cosmetic_ownership set expires_at=now()-interval '1 second' where user_id='{USER}';")
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        held = pool.submit(command, container, database,
            "set application_name='store_expiry_lock_probe';begin;" + setting +
            "select nimzo_store_purchase('fixture-concurrent',100,repeat('d',32));select pg_sleep(2);commit;")
        for _ in range(40):
            active = command(container, database,
                "select count(*) from pg_stat_activity where application_name='store_expiry_lock_probe' and wait_event='PgSleep';")
            if active.strip() == '1':
                break
            time.sleep(.03)
        else:
            raise AssertionError('Held Store settlement not observed')
        try:
            command(container, database,
                "set lock_timeout='100ms';update nimzo_cosmetic_catalog set duration_days=30 where id='fixture-concurrent';")
        except RuntimeError as error:
            assert 'lock timeout' in str(error), error
        else:
            raise AssertionError('Duration update raced Store settlement')
        assert '"status": "purchased"' in held.result()
    assert summary() == {'coins': 700, 'receipts': 3, 'owned': 1}, summary()
    print('PASS: concurrent duplicate sends and distinct renewal keys settle once; catalog duration lock serializes updates')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='nimzo-postgres-test')
    parser.add_argument('--database', default='store_expiry_v3')
    args = parser.parse_args()
    if not re.fullmatch(r'store_expiry_[a-z0-9_]+', args.database):
        parser.error('Requires a NEW disposable store_expiry_* database')
    command(args.container, 'postgres', f'create database {args.database};')
    command(args.container, args.database,
        (ROOT / 'supabase/tests/fixtures/store_ownership_expiry.sql').read_text())
    for migration in ['20261020000500_activate_original_cosmetics_store.sql',
        '20261021073500_dynamic_paid_store_purchase.sql',
        '20261021120000_dynamic_verified_media_publications.sql']:
        command(args.container, args.database,
            (ROOT / 'supabase/migrations' / migration).read_text())
    # A real pre-migration lifetime fixture verifies additive migration behavior.
    command(args.container, args.database,
        "insert into nimzo_cosmetic_ownership(user_id,item_id) values('00000000-0000-0000-0000-000000000001','nimzo-original-avatar-frame-golden-stars');")
    command(args.container, args.database,
        (ROOT / 'supabase/migrations/20261021150306_dynamic_store_ownership_expiry.sql').read_text())
    output = command(args.container, args.database,
        (ROOT / 'supabase/tests/store_ownership_expiry.sql').read_text())
    assert output.rstrip().endswith('ROLLBACK'), output
    print('PASS: lifetime preservation, durations, expiry rendering/RLS, renewals, receipts, price/media/auth safety and free-claim guards')
    concurrency_checks(args.container, args.database)
    print(f'PASS: isolated Store lifecycle checks on {args.container}/{args.database}')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Exercise the additive catalog in a disposable clone, never a remote database."""
import argparse
import hashlib
import json
from pathlib import Path
from test_gift_checked_send import command

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--container', default='nimzo-postgres-test')
    p.add_argument('--fixture', default='drive_catalog_20261022')
    p.add_argument('--database', default='drive_expanded_20261023')
    a = p.parse_args()
    if (not a.database.startswith('drive_expanded_') or not a.fixture.startswith('drive_catalog_')
            or not all(x.replace('_', '').isalnum() for x in [a.database, a.fixture])):
        p.error('Disposable fixture names required')
    from generate_expanded_drive_migration import load_catalog, build_sql, validate_proof
    old, items = load_catalog(ROOT)
    # Missing native evidence must never produce an approved production migration.
    try:
        validate_proof({}, old + items, '0' * 40)
    except ValueError:
        pass
    else:
        raise AssertionError('Missing Android evidence accepted')
    command(a.container, 'postgres', f'create database {a.database} template {a.fixture};')
    def sql(s):
        return command(a.container, a.database, s)
    user = '00000000-0000-0000-0000-000000000001'
    initial = 10_000_000
    sql(f"update wallets set coins={initial} where user_id='{user}';")
    def snapshot():
        return json.loads(sql("""select jsonb_build_object(
          'wallets',(select jsonb_agg(to_jsonb(w) order by user_id) from wallets w),
          'owned',(select jsonb_agg(to_jsonb(o) order by user_id,item_id) from nimzo_cosmetic_ownership o),
          'ledger',(select jsonb_agg(to_jsonb(l) order by to_jsonb(l)::text) from ledger l),
          'gifts',(select jsonb_agg(to_jsonb(g) order by id) from gifts g),
          'catalog',(select jsonb_agg(to_jsonb(c) order by id) from nimzo_cosmetic_catalog c),
          'gift_media',(select jsonb_agg(to_jsonb(m) order by gift_id) from gift_animation_media m),
          'store_media',(select jsonb_agg(to_jsonb(m) order by item_id) from nimzo_cosmetic_media m));""").strip())
    before = snapshot()
    # This is deliberately NOT device evidence. SQL is only sent to this disposable
    # clone; no production migration or proof JSON is written by this fixture.
    published = ROOT/'supabase/migrations/20261023061945_activate_twenty_verified_drive_gifts_store.sql'
    migration = published.read_text() if published.exists() else build_sql(
        items, '0' * 40, '2000-01-01T00:00:00Z',
        'DISPOSABLE SQL FIXTURE ONLY; NO ANDROID DEVICE APPROVAL')
    sql(migration)
    after = snapshot()
    for k in ['wallets', 'owned', 'ledger']:
        assert after[k] == before[k], f'Catalog import modified {k}'
    for k in ['gifts', 'catalog']:
        now = {r['id']: r for r in after[k]}
        assert all(now[r['id']] == r for r in before[k]), f'Old {k} changed'
    for k,key in [('gift_media','gift_id'),('store_media','item_id')]:
        now = {r[key]:r for r in after[k]}
        assert all(now[r[key]] == r for r in before[k]), f'Old {k} changed'
    collision_before = snapshot()
    try:
        sql(migration)
    except RuntimeError as e:
        assert 'product ID already exists' in str(e), str(e)
    else:
        raise AssertionError('Catalog collision did not abort')
    assert snapshot() == collision_before, 'Collision attempt changed existing data'
    spent = 0
    for v in items:
        price = v['coin_price']
        if v['category'] == 'gift':
            query = f"select send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','{v['id']}',1,'expanded-{v['id']}',{price});"
            statuses = ['ok', 'replayed']
        else:
            key = hashlib.sha256(v['id'].encode()).hexdigest()[:32]
            query = f"select nimzo_store_purchase('{v['id']}',{price},'{key}');"
            statuses = ['purchased', 'replayed']
        for status in statuses:
            out = sql(f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;" + query + 'commit;')
            receipt = next(json.loads(l) for l in out.splitlines() if l.startswith('{'))
            assert receipt['status'] == status, (v['name'], receipt)
        spent += price
        if v['category'] != 'gift':
            out = sql(f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;select nimzo_store_equip_free('{v['id']}');commit;")
            assert '\nt\n' in '\n' + out + '\n', (v['name'], out)
        assert sql(f"select coins from wallets where user_id='{user}';").strip() == str(initial-spent), v['name']
    ids = ','.join("'"+v['id']+"'" for v in items if v['category'] != 'gift')
    assert sql(f"select count(*) from nimzo_cosmetic_ownership where user_id='{user}' and item_id in ({ids}) and expires_at is null;").strip() == '28'
    print('PASS: import preserves all original rows/balances/ownership/ledger; collision aborts;20 gifts settle/replay;28 Store products purchase/replay/equip lifetime; exact debit', spent)


if __name__ == '__main__':
    main()

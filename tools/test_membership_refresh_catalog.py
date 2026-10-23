#!/usr/bin/env python3
"""Run combined presentation/gift publication only in a new disposable clone."""
import argparse
import json
import re
from generate_membership_refresh_migration import ROOT, load_items, build_sql
from test_gift_checked_send import command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='nimzo-postgres-test')
    parser.add_argument('--fixture', required=True)
    parser.add_argument('--database', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'drive_expanded_[a-z0-9_]+', args.fixture) or not re.fullmatch(r'membership_refresh_[a-z0-9_]+', args.database):
        parser.error('Disposable fixture names required')
    command(args.container, 'postgres', f'create database {args.database} template {args.fixture};')
    def sql(query):
        return command(args.container, args.database, query)
    sql("""create schema if not exists nimzo_internal;
        create table normal_vip_catalog(tier int primary key,coin_price bigint,duration_days int);
        create table svip_thresholds(level int primary key,usd_cents bigint);
        create table vip_daily_rewards(level int primary key,coins bigint);
        create table svip_friday_rewards(level int primary key,coins bigint);
        insert into normal_vip_catalog values(1,1000000,30);
        insert into svip_thresholds values(1,5000);
        insert into vip_daily_rewards values(1,3000);
        insert into svip_friday_rewards values(1,2000000);
        create table nimzo_content_revisions(channel text primary key, revision bigint default 1,updated_at timestamptz default now());
        insert into nimzo_content_revisions(channel) values('settings');
        create function nimzo_internal.bump_content_revision() returns trigger language plpgsql security definer set search_path='' as $$begin update public.nimzo_content_revisions set revision=revision+1 where channel=tg_argv[0];return null;end$$;
        """)
    for name in ['20261021120100_dynamic_membership_presentation.sql', '20261023152602_membership_animated_presentations.sql']:
        sql((ROOT / 'supabase/migrations' / name).read_text())
    user = '00000000-0000-0000-0000-000000000001'
    initial = 10000000
    sql(f"update wallets set coins={initial} where user_id='{user}';")
    tables = ['profiles','wallets','ledger','gifts','gift_animation_media','nimzo_cosmetic_catalog',
              'nimzo_cosmetic_ownership','nimzo_cosmetic_equipped','nimzo_cosmetic_media',
              'normal_vip_catalog','svip_thresholds','vip_daily_rewards','svip_friday_rewards',
              'nimzo_membership_presentations']
    def snapshot():
        return {table: json.loads(sql(f"select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) from public.{table} t;")) for table in tables}
    before = snapshot()
    membership, gifts, _ = load_items()
    # Synthetic evidence confined to this disposable database; never persisted
    # to a production migration/proof file or used to claim Android acceptance.
    migration = build_sql(membership, gifts, '0'*40, '2000-01-01T00:00:00Z',
                          'DISPOSABLE SQL FIXTURE ONLY; NOT NATIVE EVIDENCE')
    sql(migration)
    after = snapshot()
    for table in tables:
        if table in ['gifts','gift_animation_media','nimzo_membership_presentations']:
            assert all(row in after[table] for row in before[table]), table
        else:
            assert after[table] == before[table], table
    assert len(after['nimzo_membership_presentations']) == 20
    assert len(after['gifts']) == len(before['gifts']) + 7
    assert sql("select count(*) from nimzo_membership_presentations where kind='svip' and hero->>'format'='webp' and hero->'animation'->>'format'='svga';").strip() == '10'
    try:
        sql(migration)
    except RuntimeError as error:
        assert 'Refresh collision' in str(error), str(error)
    else:
        raise AssertionError('Collision did not abort')
    assert snapshot() == after
    spent = 0
    for gift in gifts:
        price = gift['coin_price']
        query = f"select send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','{gift['id']}',1,'refresh-{gift['id']}',{price});"
        for status in ['ok','replayed']:
            out = sql(f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;"+query+'commit;')
            receipt = next(json.loads(line) for line in out.splitlines() if line.startswith('{'))
            assert receipt['status'] == status, (gift['name'],receipt)
        spent += price
        assert sql(f"select coins from wallets where user_id='{user}';").strip() == str(initial-spent)
    assert spent == 5000000
    print('PASS:20 presentations preserve finances/ownership/catalogs;7 gifts send/replay once; exact debit5000000; collision rolls back.13 gifts still missing.')


if __name__ == '__main__':
    main()

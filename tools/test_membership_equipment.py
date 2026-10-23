#!/usr/bin/env python3
"""All-tier equipment integration tests in a NEW disposable Postgres database."""
import argparse
from pathlib import Path
import re
import concurrent.futures
import time
from test_gift_checked_send import command

ROOT = Path(__file__).resolve().parents[1]

def persistence_checks(container,database):
    observer='30000000-0000-0000-0000-000000000099'
    command(container,database,f"insert into profiles(id) values('{observer}');")
    for index,(kind,tier) in enumerate((k,t) for k in ['vip','svip'] for t in range(1,11)):
        user=f'30000000-0000-0000-0000-{index+1:012d}'
        command(container,database,f"insert into profiles(id,vip_level,vip_expires_at,svip_level,svip_cycle_start) values('{user}',{tier},now()+interval '1 day',{tier},now());")
        command(container,database,f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;select nimzo_membership_apply_full_set('{kind}',{tier});commit;")
        # A separate psql connection/transaction (no client cache) sees the saved
        # row, both as the owner and as another signed-in profile visitor.
        for viewer in [user,observer]:
            result=command(container,database,f"begin;select set_config('request.jwt.claim.sub','{viewer}',true);set local role authenticated;select (nimzo_membership_appearance('{user}')->>'pack_kind')||':'||(nimzo_membership_appearance('{user}')->>'pack_tier');commit;")
            assert f'\n{kind}:{tier}\n' in result,result
    print('PASS: all20 saved selections survive independent connections and observer/account changes')

def concurrency_checks(container, database):
    user='10000000-0000-0000-0000-000000000003'
    command(container,database,f"""
      insert into profiles(id,vip_level,vip_expires_at) values('{user}',5,now()+interval '1 day');
      insert into nimzo_cosmetic_catalog values('race-frame','Avatar Frame',true);
      insert into nimzo_cosmetic_ownership values('{user}','race-frame',null);
    """)
    prefix=f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;"
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        held=pool.submit(command,container,database,
          "set application_name='membership_apply_lock_probe';"+prefix+
          "select nimzo_membership_apply_full_set('vip',5);select pg_sleep(2);commit;")
        for _ in range(50):
            if command(container,database,"select count(*) from pg_stat_activity where application_name='membership_apply_lock_probe' and wait_event='PgSleep';").strip()=='1':break
            time.sleep(.03)
        else:raise AssertionError('Apply transaction lock not observed')
        try:
            command(container,database,"set lock_timeout='150ms';"+prefix+"select nimzo_store_equip_free('race-frame');commit;")
        except RuntimeError as error:
            assert 'lock timeout' in str(error),error
        else:raise AssertionError('Manual equip raced atomic full apply')
        held.result()
    result=command(container,database,prefix+"select nimzo_store_equip_free('race-frame');select nimzo_membership_appearance(auth.uid())->'pack_slots' ? 'Avatar Frame';commit;")
    assert '\nf\n' in result,result
    result=command(container,database,prefix+"select nimzo_membership_apply_full_set('vip',5);select nimzo_membership_appearance(auth.uid())->'pack_slots' ? 'Avatar Frame';commit;")
    assert '\nt\n' in result,result
    print('PASS: concurrent full-apply transaction serializes individual Store equip without partial slots')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--database', required=True)
    p.add_argument('--container', default='nimzo-postgres-test')
    a = p.parse_args()
    if not re.fullmatch(r'membership_equip_[a-z0-9_]+', a.database):
        p.error('New membership_equip_* fixture database required')
    command(a.container, 'postgres', f'create database {a.database};')
    command(a.container, a.database, (ROOT/'supabase/tests/fixtures/dynamic_memberships.sql').read_text())
    command(a.container, a.database, 'create publication supabase_realtime;')
    command(a.container, a.database, (ROOT/'supabase/migrations/20261021051156_restored_verified_memberships.sql').read_text())
    command(a.container, a.database, """
      create table public.rooms(id uuid primary key,owner_id uuid references public.profiles(id));
      create table nimzo_cosmetic_catalog(id text primary key,category text,active boolean default true);
      create table nimzo_cosmetic_ownership(user_id uuid,item_id text,expires_at timestamptz,primary key(user_id,item_id));
      create table nimzo_cosmetic_equipped(user_id uuid,category text,item_id text,equipped_at timestamptz,primary key(user_id,category));
    """)
    original = (ROOT/'supabase/migrations/20261021150306_dynamic_store_ownership_expiry.sql').read_text()
    equip = re.search(r'create or replace function public.nimzo_store_equip_free\(.*?\n\$\$;', original, re.S).group()
    command(a.container, a.database, equip)
    migrations = sorted((ROOT/'supabase/migrations').glob('*_membership_full_pack_equipment.sql'))
    if not migrations:
        # Run the acceptance test first: the missing RPC must fail before implementation.
        command(a.container, a.database, (ROOT/'supabase/tests/membership_full_pack_equipment.sql').read_text())
        raise AssertionError('Missing equipment migration')
    for migration in migrations:
        command(a.container, a.database, migration.read_text())
    output = command(a.container, a.database, (ROOT/'supabase/tests/membership_full_pack_equipment.sql').read_text())
    assert output.rstrip().endswith('ROLLBACK'), output
    concurrency_checks(a.container,a.database)
    persistence_checks(a.container,a.database)
    print('PASS: 20 tier apply/read/remove, observer visibility, entitlement denial, expiry, Store overrides and owner wallpaper')

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Test dynamic Rocket config in a NEW isolated PostgreSQL Docker database.

Loads the original Rocket migrations verbatim; never contacts production.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import concurrent.futures
import json
import threading

ROOT = Path(__file__).resolve().parent.parent


def query(container: str, database: str, sql: str) -> str:
    result = subprocess.run(['docker', 'exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', database,
                             '-v', 'ON_ERROR_STOP=1', '-At'], input=sql, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr + result.stdout)
    return result.stdout


def load_function(filename: str, name: str) -> str:
    source = (ROOT / 'supabase/migrations' / filename).read_text()
    start = source.index('create or replace function ' + name + '(')
    end = source.index('$$;', start) + 3
    return source[start:end]


def concurrent_checks(container: str, database: str) -> None:
    query(container, database, """
      insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media)
       values(2,'Concurrent configuration','Fixture',array[100,300,600]::bigint[],array[1,3,6]::smallint[],array['A','B','C'],'[null,null,null]','[null,null,null]');
      update public.room_rocket_configs set active=false where active;
      update public.room_rocket_configs set active=true where version=2;
      insert into public.rooms values('10000000-0000-0000-0000-000000000007');
      insert into public.room_members values('10000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000001');
    """)
    barrier = threading.Barrier(3)

    def run(sql: str) -> str:
        barrier.wait(timeout=10)
        return query(container, database, sql)

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(run, [
            "begin;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);select public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007');commit;",
            "insert into gift_events(id,room_id,total_coins) values('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007',150);",
            "insert into gift_events(id,room_id,total_coins) values('40000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000007',200);",
        ]))
    assert all('ERROR' not in result for result in results), results
    state = json.loads(query(container, database, """
      select jsonb_build_object('total',cy.total_coins,'version',cy.config_version,
       'targets',(select jsonb_agg(target_coins order by stage) from room_diamond_blast_events where room_id=cy.room_id),
       'versions',(select count(distinct config_version) from room_diamond_blast_events where room_id=cy.room_id))
       from nimzo_private.room_diamond_cycles cy where cy.room_id='10000000-0000-0000-0000-000000000007';
    """).strip())
    assert state == {'total': 350, 'version': 2, 'targets': [100, 300], 'versions': 1}, state

    # Publishing a successor and receiving the last gift concurrently cannot
    # change the existing cycle's threshold or suppress its remaining milestone.
    query(container, database, """
      insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media)
       values(3,'Successor configuration','Fixture',array[200,400]::bigint[],array[2,6]::smallint[],array['D','E'],'[null,null]','[null,null]');
    """)
    barrier = threading.Barrier(2)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(run, [
            "begin;update room_rocket_configs set active=false where active;update room_rocket_configs set active=true where version=3;commit;",
            "insert into gift_events(room_id,total_coins) values('10000000-0000-0000-0000-000000000007',250);",
        ]))
    assert all('ERROR' not in result for result in results), results
    state = json.loads(query(container, database, """
      select jsonb_build_object('total',cy.total_coins,'version',cy.config_version,
       'targets',(select jsonb_agg(target_coins order by stage) from room_diamond_blast_events where room_id=cy.room_id))
       from nimzo_private.room_diamond_cycles cy where cy.room_id='10000000-0000-0000-0000-000000000007';
    """).strip())
    assert state == {'total': 600, 'version': 2, 'targets': [100, 300, 600]}, state
    query(container, database, """
      insert into public.rooms values('10000000-0000-0000-0000-000000000008');
      begin;
      insert into gift_events(room_id,total_coins) values('10000000-0000-0000-0000-000000000008',500);
      rollback;
    """)
    leaked = query(container, database, """
      select (select count(*) from nimzo_private.room_diamond_cycles where room_id='10000000-0000-0000-0000-000000000008')
       +(select count(*) from room_diamond_blast_events where room_id='10000000-0000-0000-0000-000000000008');
    """)
    assert leaked.strip() == '0', leaked
    query(container, database, "insert into gift_events(room_id,total_coins) values('10000000-0000-0000-0000-000000000008',250);")
    state = query(container, database, "select config_version||':'||total_coins from nimzo_private.room_diamond_cycles where room_id='10000000-0000-0000-0000-000000000008';")
    assert state.strip() == '3:250', state
    print('PASS: concurrent initialization/gifts pin one version and settle once; concurrent publication preserves remaining milestone; rollback no pin/event leak; new cycle uses successor')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='nimzo-postgres-test')
    parser.add_argument('--database', default='rocket_dynamic_v3')
    args = parser.parse_args()
    if not re.fullmatch(r'rocket_dynamic_[a-z0-9_]+', args.database):
        parser.error('use a NEW disposable rocket_dynamic_* database')
    query(args.container, 'postgres', f'create database {args.database};')
    query(args.container, args.database, (ROOT / 'supabase/tests/fixtures/dynamic_room_rocket_config.sql').read_text())
    for filename in ['20261008231759_room_diamond_blast.sql', '20261021051449_extended_room_rockets.sql',
                     '20261021053700_single_source_six_rocket_set.sql']:
        query(args.container, args.database, (ROOT / 'supabase/migrations' / filename).read_text())
    query(args.container, args.database,
          load_function('20261021063000_dynamic_content_revisions.sql', 'nimzo_internal.bump_content_revision') +
          load_function('20261021120000_dynamic_verified_media_publications.sql', 'nimzo_internal.valid_media_publication'))
    # Produce 33 REAL original-trigger milestone rows before adding v3.
    query(args.container, args.database, """
      insert into rooms(id) select ('10000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,6) i;
      insert into gift_events(room_id,total_coins)
       select id,case when id='10000000-0000-0000-0000-000000000006' then 20000000 else 100000000 end from rooms;
      create table public.rocket_historical_before as select id,room_id,cycle_start,stage,target_coins,gift_event_id,created_at from room_diamond_blast_events;
      select case when count(*)=33 then 'PASS: 33 historical milestones seeded' else 'FAIL' end from rocket_historical_before;
    """)
    query(args.container, args.database, (ROOT / 'supabase/migrations/20261021145817_dynamic_room_rocket_cycle_config.sql').read_text())
    print(query(args.container, args.database, (ROOT / 'supabase/tests/dynamic_room_rocket_config.sql').read_text()))
    concurrent_checks(args.container, args.database)
    print(f'PASS: dynamic Rocket disposable SQL on {args.container}/{args.database}')


if __name__ == '__main__':
    main()

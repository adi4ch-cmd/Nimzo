#!/usr/bin/env python3
"""Run treasure escrow behavior in a new disposable PostgreSQL database only."""
import argparse
from pathlib import Path
import re
import concurrent.futures
import json
import threading
import time
from test_gift_checked_send import command

ROOT = Path(__file__).resolve().parents[1]

def concurrency(container, database):
    command(container,database,"""
      insert into profiles(id,display_name) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'Concurrent fixture' from generate_series(1,9)i;
      insert into wallets(user_id,coins) select id,1000000 from profiles;
      insert into rooms(id) values('10000000-0000-0000-0000-000000000001');
      insert into room_members select '10000000-0000-0000-0000-000000000001',id from profiles;
    """)
    room = '10000000-0000-0000-0000-000000000001'
    def sql(user, expression):
        return f"begin;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-{user:012}',true);{expression};commit;"
    def parallel(statements):
        gate=threading.Barrier(len(statements))
        def run(statement):
            gate.wait(timeout=10)
            try:return command(container,database,statement)
            except RuntimeError as error:return 'ERROR:'+str(error)
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(statements)) as pool:
            return list(pool.map(run,statements))
    create = f"select public.create_room_treasure('{room}','room',10000,6,'all','parallel','00000000-0000-0000-0000-000000000001')"
    funded=parallel([sql(1,create),sql(1,create)])
    assert sum('"status": "funded"' in r for r in funded)==1,funded
    assert sum('"status": "replayed"' in r for r in funded)==1,funded
    box=command(container,database,"select id from public.room_treasure_boxes;").strip()
    claim=f"select public.claim_room_treasure('{box}','{room}')"
    duplicates=parallel([sql(2,claim),sql(2,claim)])
    assert sum('"status": "claimed"' in r for r in duplicates)==1,duplicates
    assert sum('"status": "replayed"' in r for r in duplicates)==1,duplicates
    claims=parallel([sql(i,claim) for i in range(3,10)])
    assert sum('"status": "claimed"' in r for r in claims)==5,claims
    assert sum('TREASURE_UNAVAILABLE' in r for r in claims)==2,claims
    result=json.loads(command(container,database,"select jsonb_build_object('wallets',(select sum(coins) from wallets),'claims',(select count(*) from public.room_treasure_claims),'remaining',(select sum(remaining_coins) from public.room_treasure_boxes),'funds',(select count(*) from ledger where kind='treasure_fund'));").strip())
    assert result=={'wallets':9000000,'claims':6,'remaining':0,'funds':1},result
    print('PASS: concurrent funding, duplicate claims and competing final slots conserve coins')
    # A claim begun before the deadline must recheck real time after waiting
    # for another transaction's row lock, rather than using transaction now().
    command(container,database,sql(1,create.replace("'parallel'","'expiry-race'")))
    box=command(container,database,"select id from public.room_treasure_boxes where client_key='expiry-race';").strip()
    claim=f"select public.claim_room_treasure('{box}','{room}')"
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        holder=pool.submit(command,container,database,f"set application_name='treasure-expiry-holder';begin;update public.room_treasure_boxes set expires_at=clock_timestamp()+interval '1 second' where id='{box}';select pg_sleep(2);commit;")
        # Wait for the row-lock holder to enter its sleep, not a guessed delay.
        deadline=time.monotonic()+10
        while '1' not in command(container,database,"select 1 from pg_stat_activity where application_name='treasure-expiry-holder' and wait_event='PgSleep';"):
            if time.monotonic()>deadline:raise AssertionError('Expiry fixture did not acquire the row lock')
            time.sleep(.02)
        try:
            command(container,database,sql(2,claim))
            raise AssertionError('Claim waiting past expiry was accepted')
        except RuntimeError as error:
            assert 'TREASURE_UNAVAILABLE' in str(error),str(error)
        holder.result()
    refunds=parallel(['select public.refund_expired_room_treasures();','select public.refund_expired_room_treasures();'])
    assert not any('ERROR:' in r for r in refunds),refunds
    total=command(container,database,"select sum(coins) from wallets;").strip()
    assert total=='9000000',total
    assert command(container,database,"select count(*) from ledger where kind='treasure_refund';").strip()=='1'
    print('PASS: claim rechecks expiry after lock contention; concurrent refund workers credit once')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', required=True)
    parser.add_argument('--container', default='nimzo-membership-test')
    args = parser.parse_args()
    if not re.fullmatch(r'treasure_[a-z0-9_]+', args.database):
        parser.error('A NEW treasure_* fixture database is required')
    for role in ['anon', 'authenticated', 'service_role']:
        command(args.container, 'postgres', f"do $$begin if not exists(select 1 from pg_roles where rolname='{role}') then create role {role};end if;end$$;")
    command(args.container, 'postgres', f'create database {args.database};')
    command(args.container, args.database, (ROOT/'supabase/tests/fixtures/room_treasure.sql').read_text())
    migration = ROOT/'supabase/migrations/20261022171213_room_treasure_escrow.sql'
    if migration.exists():
        command(args.container, args.database, migration.read_text())
    result = command(args.container, args.database, (ROOT/'supabase/tests/room_treasure.sql').read_text())
    assert result.rstrip().endswith('ROLLBACK'), result
    print('PASS: funded treasure, exact split, eligibility, replay, escrow conservation, expiry/refund and grants')
    concurrency(args.container,args.database)

if __name__ == '__main__':
    main()

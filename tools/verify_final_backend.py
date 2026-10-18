"""Replay current public/private schema and synthetic behavioral checks. No live data."""
import argparse,json,subprocess,time,uuid
from pathlib import Path
from verify_backend_contracts import schema_sql,verify_concurrent_replays
def verify_economy_replays(command):
    from concurrent.futures import ThreadPoolExecutor
    def query(sql):
        return subprocess.run(command+['-t','-A'],input=sql,text=True,capture_output=True)
    def scalar(sql):
        r=query(sql)
        if r.returncode:raise RuntimeError(r.stderr)
        return r.stdout.strip()
    sender='00000000-0000-4000-8000-000000000102'
    actor='00000000-0000-4000-8000-000000000101'
    receiver='00000000-0000-4000-8000-000000000103'
    room=scalar(f"select room_id from room_members where user_id='{sender}'")
    scalar("insert into game_catalog(slug,name) values('fruit_party','Concurrent fixture');insert into resellers(user_id,coin_limit) values('"+actor+"',10000);")
    for changed in [False,True]:
        key='game-race-'+uuid.uuid4().hex
        before=int(scalar(f"select coins from wallets where user_id='{sender}'"))
        def play(amount):return query(f"begin;set local role authenticated;set local request.jwt.claim.sub='{sender}';select play_game('fruit_party',{amount},'spin',null,'{key}','{room}');select pg_sleep(.1);commit;")
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(play,[100,200 if changed else 100]))
        assert sum(r.returncode==0 for r in results)==(1 if changed else 2),[r.stderr for r in results]
        if changed:assert any('idempotency payload mismatch' in r.stderr for r in results)
        total=scalar(f"select bet_amount::text||':'||payout_amount::text from game_bets where user_id='{sender}' and client_key='{key}'").split(':')
        assert len(total)==2
        assert int(scalar(f"select coins from wallets where user_id='{sender}'"))==before-int(total[0])+int(total[1])
    for changed in [False,True]:
        key='reseller-race-'+uuid.uuid4().hex
        before=int(scalar(f"select coin_limit from resellers where user_id='{actor}'"))
        def recharge(target):return query(f"begin;set local role authenticated;set local request.jwt.claim.sub='{actor}';select reseller_recharge('{target}',500,'{key}');select pg_sleep(.1);commit;")
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(recharge,[receiver,sender if changed else receiver]))
        assert sum(r.returncode==0 for r in results)==(1 if changed else 2),[r.stderr for r in results]
        assert int(scalar(f"select coin_limit from resellers where user_id='{actor}'"))==before-500
        assert int(scalar(f"select count(*) from ledger where kind='reseller' and idempotency_key='{key}'"))==1
    key='exchange-race-'+uuid.uuid4().hex
    before=scalar(f"select coins::text||':'||diamonds::text from wallets where user_id='{sender}'").split(':')
    def exchange(_):return query(f"begin;set local role authenticated;set local request.jwt.claim.sub='{sender}';select exchange_diamonds(10,'{key}');select pg_sleep(.1);commit;")
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(exchange,[0,1]))
    assert all(r.returncode==0 for r in results),[r.stderr for r in results]
    after=scalar(f"select coins::text||':'||diamonds::text from wallets where user_id='{sender}'").split(':')
    assert int(after[0])==int(before[0])+10 and int(after[1])==int(before[1])-10
    print('PASS concurrent game payloads, reseller recipient/amount replay and diamond exchange settle once')

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--snapshot',type=Path,required=True);p.add_argument('--migration',type=Path,action='append',default=[]);p.add_argument('--test',type=Path,action='append',default=[]);p.add_argument('--concurrent',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1];container='nimzo-final-'+uuid.uuid4().hex[:10]
subprocess.run(['docker','run','-d','--name',container,'-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine'],check=True,stdout=subprocess.DEVNULL)
try:
 for _ in range(80):
  if subprocess.run(['docker','exec',container,'pg_isready','-h','127.0.0.1','-U','postgres'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:break
  time.sleep(.25)
 else:raise RuntimeError('Disposable database did not start')
 command=['docker','exec','-i',container,'psql','-X','-q','-U','postgres','-v','ON_ERROR_STOP=1']
 def run(sql):
  r=subprocess.run(command,input=sql,text=True,capture_output=True)
  if r.returncode:raise RuntimeError(r.stderr)
  print(r.stdout.strip())
 snapshot=json.loads(a.snapshot.read_text())
 run(schema_sql(snapshot))
 if snapshot.get('storage_policies'):
  run("create schema storage; create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text); alter table storage.objects enable row level security; grant usage on schema storage to authenticated,anon;grant select,insert,update,delete on storage.objects to authenticated;create function storage.foldername(name text) returns text[] language sql immutable as $$select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]$$;")
  for policy in snapshot['storage_policies']:
   statement='create policy '+policy['name']+' on storage.objects for '+policy['cmd']+' to '+','.join(policy['roles'])
   if policy['qual']:statement+=' using ('+policy['qual']+')'
   if policy['check']:statement+=' with check ('+policy['check']+')'
   run(statement+';')
 run("""create schema vault; create table vault.secrets(id uuid default gen_random_uuid(),name text unique,secret text);
 create view vault.decrypted_secrets as select id,name,secret decrypted_secret from vault.secrets;
 create function vault.create_secret(new_secret text,new_name text,new_description text default null) returns uuid language plpgsql as $$declare result uuid;begin insert into vault.secrets(name,secret) values(new_name,new_secret) returning id into result;return result;end$$;
 insert into vault.secrets(name,secret) values('nimzo_push_dispatch_hmac',repeat('ab',32)),('nimzo_push_gateway_anon','public-fixture-key');
 create schema net; create table net.http_request_queue(id bigserial primary key,headers jsonb); create table net._http_response(id bigint,content text); grant all on net.http_request_queue,net._http_response to public; create function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds int) returns bigint language sql as $$select 1::bigint$$;
 """)
 for path in a.migration:
  # Managed pg_net is represented by the local net.http_post stub above.
  run(path.read_text().replace('create extension if not exists pg_net with schema extensions;',''))
 baseline=(root/'supabase/tests/backend_targeted_repair.sql').read_text().rstrip()
 assert baseline.endswith('rollback;');run(baseline[:-len('rollback;')]+'commit;')
 for path in a.test:run(path.read_text())
 if a.concurrent:
  verify_concurrent_replays(command)
  verify_economy_replays(command)
 print('PASS: current full-schema authorization, behavior and requested regressions')
finally:subprocess.run(['docker','rm','-f',container],check=False,stdout=subprocess.DEVNULL)

#!/usr/bin/env python3
"""Check the preserved original 1:1 exchange in a fresh disposable fixture DB."""
import argparse
from pathlib import Path
import re
import concurrent.futures
import threading
from test_gift_checked_send import command
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--database',required=True);p.add_argument('--container',default='nimzo-membership-test');a=p.parse_args()
 if not re.fullmatch(r'exchange_[a-z0-9_]+',a.database):p.error('A NEW exchange_* fixture database is required')
 for role in ['anon','authenticated','service_role']:
  command(a.container,'postgres',f"do $$begin if not exists(select 1 from pg_roles where rolname='{role}') then create role {role};end if;end$$;")
 command(a.container,'postgres',f'create database {a.database};')
 command(a.container,a.database,(ROOT/'supabase/tests/fixtures/room_treasure.sql').read_text())
 s=(ROOT/'supabase/migrations/20261018142454_notification_events_and_account_guards.sql').read_text()
 start=s.index('CREATE OR REPLACE FUNCTION public.exchange_diamonds(');end=s.index('$function$;',start)+len('$function$;')
 command(a.container,a.database,s[start:end])
 command(a.container,a.database,(ROOT/'supabase/migrations/20261022174046_checked_diamond_exchange.sql').read_text())
 result=command(a.container,a.database,(ROOT/'supabase/tests/checked_diamond_exchange.sql').read_text())
 assert result.rstrip().endswith('ROLLBACK'),result
 print('PASS: original 1:1 exchange, receipt-first replay, account binding, balance conservation and anonymous denial')
 command(a.container,a.database,"insert into profiles(id) values('00000000-0000-0000-0000-000000000001');insert into wallets(user_id,coins,diamonds) select id,1000,2000 from profiles;")
 def parallel(statements):
  gate=threading.Barrier(len(statements))
  def run(statement):
   gate.wait(timeout=10)
   try:return command(a.container,a.database,"begin;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);"+statement+';commit;')
   except RuntimeError as e:return 'ERROR:'+str(e)
  with concurrent.futures.ThreadPoolExecutor(max_workers=len(statements)) as pool:return list(pool.map(run,statements))
 result=parallel(["select public.exchange_diamonds_checked(100,'parallel',auth.uid())"]*2)
 assert sum('"status": "exchanged"' in r for r in result)==1,result
 assert sum('"status": "replayed"' in r for r in result)==1,result
 legacy=parallel(["select public.exchange_diamonds_checked(100,'legacy-race',auth.uid())","select public.exchange_diamonds(100,'legacy-race')"])
 assert all('ERROR:' not in r for r in legacy),legacy
 changed=parallel([f"select public.exchange_diamonds_checked({amount},'changed-amount',auth.uid())" for amount in [100,200]])
 assert sum('ERROR:' not in r for r in changed)==1,changed
 assert sum('EXCHANGE_PAYLOAD_MISMATCH' in r for r in changed)==1,changed
 assert command(a.container,a.database,'select coins+diamonds from wallets;').strip()=='3000'
 assert command(a.container,a.database,"select count(*) from ledger where kind='exchange';").strip()=='3'
 print('PASS: duplicate, legacy/checked and changed-amount concurrent exchanges settle once at 1:1')
if __name__=='__main__':main()

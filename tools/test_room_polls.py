#!/usr/bin/env python3
"""Verify real room polls only in a fresh disposable fixture database."""
import argparse
from pathlib import Path
import re
import concurrent.futures
import threading
from test_gift_checked_send import command
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--database',required=True);p.add_argument('--container',default='nimzo-membership-test');a=p.parse_args()
 if not re.fullmatch(r'polls_[a-z0-9_]+',a.database):p.error('A NEW polls_* fixture database is required')
 for role in ['anon','authenticated','service_role']:
  command(a.container,'postgres',f"do $$begin if not exists(select 1 from pg_roles where rolname='{role}') then create role {role};end if;end$$;")
 command(a.container,'postgres',f'create database {a.database};')
 command(a.container,a.database,(ROOT/'supabase/tests/fixtures/room_treasure.sql').read_text())
 command(a.container,a.database,"alter table rooms add column perm_chat bool default true,add column chat_permission text default 'members';create function public.can_moderate(uuid,uuid) returns bool language sql as $$select false$$;")
 migration=next((ROOT/'supabase/migrations').glob('*_room_polls.sql'))
 command(a.container,a.database,migration.read_text())
 result=command(a.container,a.database,(ROOT/'supabase/tests/room_polls.sql').read_text())
 assert result.rstrip().endswith('ROLLBACK'),result
 print('PASS: real poll creation, normalized options, counts, one-vote replay, close, membership/account authorization and RLS')
 command(a.container,a.database,"""insert into profiles(id) values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
 insert into rooms(id) values('10000000-0000-0000-0000-000000000001');
 insert into room_members select '10000000-0000-0000-0000-000000000001',id from profiles;""")
 def sql(user,body):return f"begin;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-{user:012}',true);{body};commit;"
 def parallel(statements):
  gate=threading.Barrier(len(statements))
  def run(statement):
   gate.wait(timeout=10)
   try:return command(a.container,a.database,statement)
   except RuntimeError as e:return 'ERROR:'+str(e)
  with concurrent.futures.ThreadPoolExecutor(max_workers=len(statements)) as pool:return list(pool.map(run,statements))
 creates=parallel([sql(i,f"select public.create_room_poll('10000000-0000-0000-0000-000000000001','Race?',array['A','B'],'create-{i}',auth.uid())") for i in [1,2]])
 assert sum('ERROR:' not in r for r in creates)==1,creates
 assert sum('POLL_ALREADY_ACTIVE' in r for r in creates)==1,creates
 poll=command(a.container,a.database,'select id from public.room_polls;').strip()
 votes=parallel([sql(1,f"select public.cast_room_vote('{poll}',{i},auth.uid())") for i in [0,1]])
 assert sum('ERROR:' not in r for r in votes)==1,votes
 assert sum('VOTE_ALREADY_CAST' in r for r in votes)==1,votes
 assert command(a.container,a.database,'select count(*) from public.room_poll_votes;').strip()=='1'
 print('PASS: competing poll creation and simultaneous changed votes serialize safely')
if __name__=='__main__':main()

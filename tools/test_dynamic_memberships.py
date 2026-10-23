#!/usr/bin/env python3
"""Use a NEW disposable Docker PostgreSQL database; never a live backend."""
import argparse
from pathlib import Path
import re
from test_gift_checked_send import command
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--database',required=True);p.add_argument('--container',default='nimzo-membership-test');a=p.parse_args()
 if not re.fullmatch(r'membership_[a-z0-9_]+',a.database):p.error('New membership_* fixture database required')
 for role in ['anon','authenticated','service_role']:
  command(a.container,'postgres',f"do $$begin if not exists(select 1 from pg_roles where rolname='{role}') then create role {role}; end if;end$$;")
 command(a.container,'postgres',f'create database {a.database};')
 command(a.container,a.database,(ROOT/'supabase/tests/fixtures/dynamic_memberships.sql').read_text())
 command(a.container,a.database,'create publication supabase_realtime;')
 command(a.container,a.database,(ROOT/'supabase/migrations/20261021051156_restored_verified_memberships.sql').read_text())
 command(a.container,a.database,"""create schema nimzo_internal;
 create table public.nimzo_content_revisions(channel text primary key, revision bigint default 1,updated_at timestamptz default now());
 insert into public.nimzo_content_revisions(channel) values('settings');
 create function nimzo_internal.bump_content_revision() returns trigger language plpgsql security definer set search_path='' as $$begin update public.nimzo_content_revisions set revision=revision+1 where channel=tg_argv[0];return null;end$$;""")
 command(a.container,a.database,(ROOT/'supabase/migrations/20261021120100_dynamic_membership_presentation.sql').read_text())
 command(a.container,a.database,(ROOT/'supabase/migrations/20261023152602_membership_animated_presentations.sql').read_text())
 for test in ['restored_memberships','dynamic_membership_presentation','membership_checked_purchase','membership_animated_presentations']:
  result=command(a.container,a.database,(ROOT/f'supabase/tests/{test}.sql').read_text())
  if not result.rstrip().endswith('ROLLBACK'):raise AssertionError(test+': fixture must rollback')
  print('PASS: '+test)
 print('PASS: isolated membership rules, artwork RLS, price and replay safety')
if __name__=='__main__':main()

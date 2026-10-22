#!/usr/bin/env python3
"""Exercise original game settlement and read-only recovery in a NEW fixture DB."""
import argparse
from pathlib import Path
import re
from test_gift_checked_send import command
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--database',required=True);p.add_argument('--container',default='nimzo-membership-test');a=p.parse_args()
 if not re.fullmatch(r'game_receipt_[a-z0-9_]+',a.database):p.error('A NEW game_receipt_* fixture database is required')
 for role in ['anon','authenticated','service_role']:
  command(a.container,'postgres',f"do $$begin if not exists(select 1 from pg_roles where rolname='{role}') then create role {role};end if;end$$;")
 command(a.container,'postgres',f'create database {a.database};')
 command(a.container,a.database,(ROOT/'supabase/tests/fixtures/game_receipt.sql').read_text())
 source=(ROOT/'supabase/migrations/20261018142455_game_retry_payload_guard.sql').read_text()
 command(a.container,a.database,'CREATE OR REPLACE FUNCTION'+source.split('CREATE OR REPLACE FUNCTION',1)[1])
 migration=ROOT/'supabase/migrations/20261022171412_recover_confirmed_game_receipts.sql'
 if migration.exists():command(a.container,a.database,migration.read_text())
 result=command(a.container,a.database,(ROOT/'supabase/tests/game_receipt_recovery.sql').read_text())
 assert result.rstrip().endswith('ROLLBACK'),result
 print('PASS: original real settlement recovered after room departure/catalog deactivation; scope, payload, auth and balances preserved')
if __name__=='__main__':main()

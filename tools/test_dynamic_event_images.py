#!/usr/bin/env python3
"""Disposable PostgreSQL checks only; never contacts Supabase."""
import argparse,re
from pathlib import Path
from test_gift_checked_send import command
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--database',required=True);p.add_argument('--container',default='nimzo-postgres-test');a=p.parse_args()
 if not re.fullmatch(r'event_images_[a-z0-9_]+',a.database):p.error('NEW event_images_* database required')
 command(a.container,'postgres',f'create database {a.database};')
 fixture=(ROOT/'tools/tests/dynamic_media_publication_test.sql').read_text().replace('\\ir ../../supabase/migrations/20261021120000_dynamic_verified_media_publications.sql',(ROOT/'supabase/migrations/20261021120000_dynamic_verified_media_publications.sql').read_text())
 command(a.container,a.database,fixture)
 command(a.container,a.database,"create table public.banners(id text primary key,title text,image_path text,active boolean);insert into public.banners values('legacy','Old','old.png',true);")
 command(a.container,a.database,(ROOT/'supabase/migrations/20261021151626_dynamic_game_event_presentation.sql').read_text())
 result=command(a.container,a.database,"""begin;
 do $$begin
  if not exists(select 1 from banners where id='legacy' and image_path='old.png' and active)then raise exception 'legacy altered';end if;
  update banners set title='Old preserved' where id='legacy';
  insert into banners(id,title,image_path,active) values('staged','Staged','https://cdn.example/unverified.png',false);
  begin update banners set active=true where id='staged';raise exception 'unverified activated';exception when invalid_parameter_value then null;end;
  begin insert into banners(id,title,image_path,active) values('new','Bad','https://cdn.example/invalid.png',true);raise exception 'new unverified active';exception when invalid_parameter_value then null;end;
  update banners set image_path='https://cdn.example/'||repeat('a',64)||'.png',image_sha256=repeat('a',64),image_byte_size=128,image_mime_type='image/png',image_rights_reference='owner fixture',image_verified_at=now(),image_device_verified_at=now(),active=true where id='staged';
  begin update banners set image_path='https://cdn.example/mutable.png' where id='staged';raise exception 'hash mismatch accepted';exception when invalid_parameter_value then null;end;
  begin update banners set image_byte_size=4194305 where id='staged';raise exception 'oversize accepted';exception when invalid_parameter_value then null;end;
 end$$;rollback;""")
 assert result.rstrip().endswith('ROLLBACK');print('PASS: legacy campaigns preserved; staged approvals, hash, size and new active guards verified')
if __name__=='__main__':main()

#!/usr/bin/env python3
"""New disposable clone of the gift QA fixture only; never connects to live DB."""
import argparse
import json
from pathlib import Path
from test_gift_checked_send import command

root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--container',default='nimzo-postgres-test')
p.add_argument('--gift-fixture',default='gift_checked_drive_20261022')
p.add_argument('--database',default='drive_catalog_20261022')
a=p.parse_args()
if not a.database.startswith('drive_catalog_') or not a.gift_fixture.startswith('gift_checked_') or not all(x.replace('_','').isalnum() for x in [a.database,a.gift_fixture]):
    p.error('Disposable fixture database names required')
command(a.container,'postgres',f'create database {a.database} template {a.gift_fixture};')
def sql(s): return command(a.container,a.database,s)
sql('''create table auth.users(id uuid primary key);
insert into auth.users select id from profiles;
alter table public.gifts add column name text,add column category text,add column asset_path text;
alter table public.gift_animation_media add column if not exists duration_ms integer,add column if not exists aspect_ratio numeric,add column if not exists transparent boolean;
alter table public.nimzo_cosmetic_catalog add column name text,add column category text,add column variant integer;
alter table public.nimzo_cosmetic_media add column thumbnail_url text,add column updated_at timestamptz default now();
-- Match the live constraints read from pg_constraint (historical schema includes ID Frame).
alter table public.nimzo_cosmetic_catalog add constraint drive_fixture_category_check check(category in ('Avatar Frame','Party Theme','Rides','Chat Bubble','Live Frame','Royal Badge','Mic Wave','Profile Card','ID Frame'));
alter table public.nimzo_cosmetic_catalog add constraint drive_fixture_variant_check check(variant between 0 and 6);
''')
for name in ['20261020000500_activate_original_cosmetics_store.sql','20261021073500_dynamic_paid_store_purchase.sql','20261021150306_dynamic_store_ownership_expiry.sql']:
    sql((root/'supabase/migrations'/name).read_text())
user='00000000-0000-0000-0000-000000000001'
sql(f"update wallets set coins=100000 where user_id='{user}';insert into nimzo_cosmetic_ownership(user_id,item_id) values('{user}','nimzo-original-avatar-frame-golden-stars');")
def snapshot():
    return json.loads(sql("select jsonb_build_object('wallets',(select jsonb_agg(to_jsonb(w) order by user_id) from wallets w),'owned',(select jsonb_agg(to_jsonb(o) order by user_id,item_id) from nimzo_cosmetic_ownership o),'ledger',(select count(*) from ledger));").strip())
before=snapshot()
sql((root/'supabase/migrations/20261022190130_activate_verified_drive_gifts_store.sql').read_text())
assert snapshot()==before, 'Import modified existing balances, ledger or ownership'
items=json.loads((root/'nimzo/assets/drive_catalog/manifest.json').read_text())['items']
spent=0
for item in items:
    if item['category']=='gift':
        query=f"select public.send_gift_checked('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','{item['id']}',1,'drive-{item['id']}',{item['coin_price']});"
        expected=['ok','replayed']
    else:
        key=item['sha256'][:32]
        query=f"select public.nimzo_store_purchase('{item['id']}',{item['coin_price']},'{key}');"
        expected=['purchased','replayed']
    for status in expected:
        out=sql(f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;"+query+'commit;')
        receipt=next(json.loads(l) for l in out.splitlines() if l.startswith('{'))
        assert receipt['status']==status,(item['name'],receipt)
    spent+=item['coin_price']
    if item['category']!='gift':
        out=sql(f"begin;select set_config('request.jwt.claim.sub','{user}',true);set local role authenticated;select nimzo_store_equip_free('{item['id']}');commit;")
        assert '\nt\n' in '\n'+out+'\n',(item['name'],out)
assert sql(f"select coins from wallets where user_id='{user}';").strip()==str(100000-spent)
assert sql(f"select count(*) from nimzo_cosmetic_ownership where user_id='{user}';").strip()=='8'
assert sql(f"select count(*) from nimzo_cosmetic_ownership where user_id='{user}' and item_id like 'nimzo-drive-%' and expires_at is null;").strip()=='7'
print('PASS: actual migration preserves fixture balances/ledger/ownership; both gifts settle/replay; all7 Store items purchase/replay/equip; exact total debit',spent)

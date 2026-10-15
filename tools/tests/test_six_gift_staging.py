"""Run only against a disposable local PostgreSQL container; no Supabase credentials."""
import os
from pathlib import Path
import subprocess
import time
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[2]
MIGRATION=ROOT/'supabase/migrations/20261015215848_stage_six_realistic_gifts.sql'
RED='8b4dfa2b-192e-4c90-89dd-8d9598d142c8'

class StagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.name='nimzo-six-stage-'+uuid.uuid4().hex[:10]
        cls.docker=['docker','--host=unix:///var/run/docker.sock']
        cls.env={k:v for k,v in os.environ.items() if k not in ['DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH']}
        subprocess.run(cls.docker+['run','-d','--name',cls.name,'-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine'],env=cls.env,check=True,capture_output=True)
        for _ in range(50):
            if subprocess.run(cls.docker+['exec',cls.name,'pg_isready','-h','127.0.0.1','-U','postgres'],env=cls.env,capture_output=True).returncode==0:break
            time.sleep(.2)
        else:raise RuntimeError('Disposable PostgreSQL unavailable')
    @classmethod
    def tearDownClass(cls):
        subprocess.run(cls.docker+['rm','-f',cls.name],env=cls.env,capture_output=True,check=False)
    def sql(self,sql,check=True):
        return subprocess.run(self.docker+['exec','-i',self.name,'psql','-h','127.0.0.1','-X','-q','-t','-A','-U','postgres','-v','ON_ERROR_STOP=1'],input=sql,text=True,env=self.env,capture_output=True,check=check)
    def setUp(self):
        self.sql('''drop table if exists public.gifts;
        create table public.gifts(id uuid primary key,name text not null,category text not null,
        coin_price bigint not null check(coin_price>0),asset_path text,min_vip int not null default 0,
        min_svip int not null default 0,active boolean not null default true);
        alter table public.gifts enable row level security;
        insert into public.gifts values
        ('35e4c570-cb02-4466-ae86-d670b3fb05ab','Sports Car','premium',100000,'existing.svga',0,0,true),
        ('c3f41e6e-68d5-4e56-9253-33421ec18fc3','Golden Dragon','dragon',5000000,'existing.mp4',0,0,true);''')
        self.before=self.sql('select jsonb_agg(to_jsonb(g) order by id) from gifts g').stdout.strip()
    def migrate(self,check=True):return self.sql(MIGRATION.read_text(),check)
    def test_stages_only_six_inactive_500k_gifts_without_touching_existing(self):
        self.migrate()
        self.assertEqual(self.sql('select count(*) from gifts where not active and coin_price=500000 and asset_path is null').stdout.strip(),'6')
        self.assertEqual(self.sql('select count(*) from gifts').stdout.strip(),'8')
        after=self.sql("select jsonb_agg(to_jsonb(g) order by id) from gifts g where id in ('35e4c570-cb02-4466-ae86-d670b3fb05ab','c3f41e6e-68d5-4e56-9253-33421ec18fc3')").stdout.strip()
        self.assertEqual(self.before,after)
    def test_replay_preserves_future_approved_artwork_and_activation(self):
        self.migrate();self.sql(f"update gifts set asset_path='approved.webp',active=true where id='{RED}'")
        self.migrate()
        self.assertEqual(self.sql(f"select asset_path||':'||active from gifts where id='{RED}'").stdout.strip(),'approved.webp:true')
        self.assertEqual(self.sql('select count(*) from gifts').stdout.strip(),'8')
    def test_conflicting_identity_aborts_without_partial_inserts(self):
        self.sql(f"insert into gifts(id,name,category,coin_price) values('{RED}','Unrelated','premium',1)")
        result=self.migrate(False)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('identity conflict',result.stderr)
        self.assertEqual(self.sql('select count(*) from gifts').stdout.strip(),'3')
    def test_same_name_at_different_id_aborts(self):
        self.sql("insert into gifts(id,name,category,coin_price) values('00000000-0000-4000-8000-000000000001','Royal Tiger','premium',500000)")
        result=self.migrate(False)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('name conflict',result.stderr)
        self.assertEqual(self.sql('select count(*) from gifts').stdout.strip(),'3')
    def test_never_overwrites_changed_price(self):
        self.migrate();self.sql(f"update gifts set coin_price=700000 where id='{RED}'")
        result=self.migrate(False)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('price conflict',result.stderr)
        self.assertEqual(self.sql(f"select coin_price from gifts where id='{RED}'").stdout.strip(),'700000')

if __name__=='__main__':unittest.main()

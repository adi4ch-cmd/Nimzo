-- NEW DISPOSABLE DATABASE ONLY; all new test data/configuration rolls back.
begin;
create function pg_temp.check_true(p_condition boolean,p_label text) returns void language plpgsql as $$
begin if p_condition is not true then raise exception 'FAIL: %',p_label; end if; end;
$$;
create function pg_temp.expect_error(p_sql text,p_message text) returns void language plpgsql as $$
begin
 begin execute p_sql;
 exception when others then
  if position(p_message in sqlerrm)>0 then return; end if;
  raise exception 'Expected %, got %',p_message,sqlerrm;
 end;
 raise exception 'Expected %, statement succeeded',p_message;
end;
$$;
select pg_temp.check_true((select count(*) from public.rocket_historical_before)=33,'33 original milestones present');
select pg_temp.check_true(not exists(
 (select id,room_id,cycle_start,stage,target_coins,gift_event_id,created_at from public.room_diamond_blast_events
  except select * from public.rocket_historical_before)
 union all
 (select * from public.rocket_historical_before except
  select id,room_id,cycle_start,stage,target_coins,gift_event_id,created_at from public.room_diamond_blast_events)
),'original historical fields byte-for-byte unchanged');
select pg_temp.check_true((select bool_and(config_version=1 and artwork_stage=stage+1) from public.room_diamond_blast_events),'original event config/art mapping');
select pg_temp.check_true((select bool_and(config_version=1) from nimzo_private.room_diamond_cycles),'all original cycles pinned default');
select pg_temp.check_true(not has_table_privilege('authenticated','public.room_rocket_configs','INSERT'),'clients cannot publish');
select pg_temp.check_true(not has_table_privilege('authenticated','public.room_rocket_configs','UPDATE'),'clients cannot edit');
select pg_temp.check_true(not has_table_privilege('anon','public.room_rocket_configs','SELECT'),'anonymous config denied');
select pg_temp.check_true(not has_function_privilege('anon','public.room_rocket_status_v3(uuid)','EXECUTE'),'anonymous status denied');
select pg_temp.check_true(not has_function_privilege('authenticated','nimzo_private.current_room_rocket_config_version()','EXECUTE'),'private pin selection denied');

insert into public.room_members(room_id,user_id) select id,'00000000-0000-0000-0000-000000000001' from public.rooms;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000001')->>'config_version'='1','member default status');
select pg_temp.check_true(jsonb_array_length(public.room_diamond_status('10000000-0000-0000-0000-000000000001')->'thresholds')=6,'old endpoint preserved');
select pg_temp.check_true(public.room_diamond_status('10000000-0000-0000-0000-000000000001')=public.room_rocket_status_v2('10000000-0000-0000-0000-000000000001'),'v2 compatibility preserved');
reset role;

-- Strict structure limits the dynamic data to existing native engines.
select pg_temp.expect_error($q$insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media) values(2,'Invalid','',array[100,99]::bigint[],array[1,2]::smallint[],array['A','B'],'[null,null]','[null,null]')$q$,'check constraint');
select pg_temp.expect_error($q$insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media) values(2,'Invalid','',array[100]::bigint[],array[7]::smallint[],array['A'],'[null]','[null]')$q$,'check constraint');
select pg_temp.expect_error($q$insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media) values(2,'Invalid','',array[0]::bigint[],array[1]::smallint[],array['A'],'[null]','[null]')$q$,'check constraint');
select pg_temp.expect_error($q$insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media) values(2,'Invalid','',array[1,2,3,4,5,6,7]::bigint[],array[1,2,3,4,5,6,1]::smallint[],array['A','B','C','D','E','F','G'],'[null,null,null,null,null,null,null]','[null,null,null,null,null,null,null]')$q$,'check constraint');

-- Drafts are hidden and editable. Publishing version 2 bumps settings revision.
insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media)
 values(2,'Three-stage launch','Verified room gifts',array[100,300,600]::bigint[],array[1,3,6]::smallint[],array['Spark','Orbit','Nova'],'[null,null,null]','[null,null,null]');
update public.room_rocket_configs set title='Three-stage Rocket' where version=2;
set local role authenticated;
select pg_temp.check_true((select count(*) from public.room_rocket_configs)=1,'unpublished draft hidden');
reset role;
create temp table revision_before as select revision from public.nimzo_content_revisions where channel='settings';
update public.room_rocket_configs set active=false where active;
update public.room_rocket_configs set active=true where version=2;
select pg_temp.check_true((select revision from public.nimzo_content_revisions where channel='settings')>(select revision from revision_before),'settings revision invalidated');
select pg_temp.expect_error($q$update public.room_rocket_configs set thresholds=array[1,2,3]::bigint[] where version=2$q$,'immutable');
select pg_temp.expect_error($q$delete from public.room_rocket_configs where version=2$q$,'cannot be deleted');
select pg_temp.expect_error($q$update nimzo_private.room_diamond_cycles set config_version=2 where room_id='10000000-0000-0000-0000-000000000001'$q$,'pinned');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000001')->>'config_version'='1','old cycle ignores newly published config');
insert into public.gift_events(room_id,total_coins) values('10000000-0000-0000-0000-000000000001',1000000);
select pg_temp.check_true((select count(*) from public.room_diamond_blast_events)=33,'old completed cycle never relaunches');

-- New rooms choose version 2 ONCE. Batch insert counts each actual gift once
-- and binds each event to both its threshold and native visual index.
insert into public.rooms(id) values('10000000-0000-0000-0000-000000000007');
insert into public.room_members values('10000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000001');
insert into public.gift_events(id,room_id,total_coins) values
 ('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007',150),
 ('40000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000007',200);
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'config_version'='2','new cycle pinned v2');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->'thresholds'='[100,300,600]'::jsonb,'real dynamic thresholds');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->'artwork_stages'='[1,3,6]'::jsonb,'real dynamic compiled art');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->'stage_labels'='["Spark","Orbit","Nova"]'::jsonb,'real dynamic labels');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'completed_stages'='2','dynamic completion count');
select pg_temp.check_true(abs((public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'progress')::numeric-(50.0/300))<0.00001,'dynamic within-stage progress');
select pg_temp.check_true((select total_coins from nimzo_private.room_diamond_cycles where room_id='10000000-0000-0000-0000-000000000007')=350,'batch excludes all new rows from baseline');
select pg_temp.check_true((select array_agg(target_coins order by stage) from public.room_diamond_blast_events where room_id='10000000-0000-0000-0000-000000000007')=array[100,300]::bigint[],'events exact configured targets');
select pg_temp.check_true((select array_agg(artwork_stage order by stage) from public.room_diamond_blast_events where room_id='10000000-0000-0000-0000-000000000007')=array[1,3]::smallint[],'events exact configured visuals');
insert into public.gift_events(id,room_id,total_coins) values('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007',150) on conflict do nothing;
select pg_temp.check_true((select total_coins from nimzo_private.room_diamond_cycles where room_id='10000000-0000-0000-0000-000000000007')=350,'duplicate gift does not count twice');
select pg_temp.expect_error($q$insert into public.room_diamond_blast_events(room_id,cycle_start,stage,target_coins,gift_event_id,config_version,artwork_stage) select room_id,cycle_start,2,500,gen_random_uuid(),2,6 from nimzo_private.room_diamond_cycles where room_id='10000000-0000-0000-0000-000000000007'$q$,'does not match pinned');

-- Partial deactivation leaves pinned cycles and published media readable. With
-- no active config a future room gets the complete original fallback, not zero.
update public.room_rocket_configs set active=false where version=2;
set local role authenticated;
select pg_temp.check_true((select count(*) from public.room_rocket_configs where version=2)=1,'deactivated pinned version remains readable');
reset role;
insert into public.gift_events(room_id,total_coins) values('10000000-0000-0000-0000-000000000007',250);
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'completed_stages'='3','deactivated config still settles pinned milestones');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'progress'='1','last stage capped');
insert into public.rooms(id) values('10000000-0000-0000-0000-000000000008');
insert into public.room_members values('10000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000001');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000008')->>'config_version'='1','no active config uses original fallback');

-- Remote effects can only publish existing VAP codec and verified immutable
-- media descriptors. Invalid draft remains invisible; executable JSON rejected.
insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media)
 values(3,'Remote Nova','New supported media',array[50,150]::bigint[],array[2,6]::smallint[],array['Rise','Nova'],
 '[{"url":"http://unapproved.example/effect.mp4","codec":"javascript"},null]','[null,null]');
select pg_temp.expect_error($q$update public.room_rocket_configs set active=true where version=3$q$,'verified immutable VAP');
update public.room_rocket_configs set fly_media=jsonb_build_array(jsonb_build_object(
 'url','https://approved.example/'||repeat('b',64)||'.mp4','sha256',repeat('b',64),'byte_size',1000,
 'mime_type','video/mp4','codec','vap','rights_reference','disposable licensed fixture',
 'verified_at',statement_timestamp(),'device_verified_at',statement_timestamp(),'sound_mode','embedded'),null),
 reward_media=jsonb_build_array(null,jsonb_build_object(
 'url','https://approved.example/'||repeat('c',64)||'.mp4','sha256',repeat('c',64),'byte_size',1200,
 'mime_type','video/mp4','codec','vap','rights_reference','disposable licensed fixture',
 'verified_at',statement_timestamp(),'device_verified_at',statement_timestamp(),'sound_mode','synthesized')) where version=3;
update public.room_rocket_configs set active=true where version=3;
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'config_version'='2','publication never changes pinned completed cycle');

-- Controlled clock fixture ONLY in this rollback transaction. Production's
-- timezone helper is never altered by the migration. Exercise its real daily
-- boundary math plus one simulated future day through the ORIGINAL trigger.
select pg_temp.check_true(nimzo_private.room_diamond_cycle_start('2026-10-21 19:59:59+00')='2026-10-20 20:00+00'::timestamptz,'Saudi reset before boundary');
select pg_temp.check_true(nimzo_private.room_diamond_cycle_start('2026-10-21 20:00:00+00')='2026-10-21 20:00+00'::timestamptz,'Saudi reset boundary');
create or replace function nimzo_private.room_diamond_cycle_start(p_now timestamptz)
returns timestamptz language sql stable set search_path='' as $$
 select (date_trunc('day',coalesce(nullif(current_setting('nimzo.fixture_now',true),'')::timestamptz,p_now) at time zone 'UTC' - interval '20 hours') + interval '20 hours') at time zone 'UTC'
$$;
select set_config('nimzo.fixture_now',(statement_timestamp()+interval '24 hours')::text,true);
insert into public.gift_events(room_id,total_coins,created_at) values('10000000-0000-0000-0000-000000000007',75,statement_timestamp()+interval '24 hours');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'config_version'='3','daily rollover chooses new version');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->>'total_coins'='75','daily rollover excludes yesterday gifts');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->'fly_media'->0->>'codec'='vap','pinned remote descriptor returned');
select pg_temp.check_true(public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')->'reward_media'->1->>'sound_mode'='synthesized','pinned sound policy returned');
select pg_temp.check_true((select count(*) from nimzo_private.room_diamond_cycles where room_id='10000000-0000-0000-0000-000000000007')=2,'both cycle snapshots retained');
select pg_temp.check_true((select count(*) from public.room_diamond_blast_events where room_id='10000000-0000-0000-0000-000000000007' and config_version=2)=3,'old cycle history unchanged');
select pg_temp.check_true((select target_coins from public.room_diamond_blast_events where room_id='10000000-0000-0000-0000-000000000007' and config_version=3)=50,'new cycle target retained');
select pg_temp.check_true((select artwork_stage from public.room_diamond_blast_events where room_id='10000000-0000-0000-0000-000000000007' and config_version=3)=2,'new cycle artwork retained');

-- Restricted clients cannot inspect non-member progress or forge events/config.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.expect_error($q$select public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')$q$,'room membership required');
select pg_temp.check_true((select count(*) from public.room_diamond_blast_events)=0,'non-member event RLS');
select pg_temp.expect_error($q$update public.room_rocket_configs set active=false$q$,'permission denied');
reset role;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error($q$select public.room_rocket_status_v3('10000000-0000-0000-0000-000000000007')$q$,'authentication required');
select 'PASS: 33 historical milestones retained; config permissions/validation; pinning/publication/deactivation; actual settled progress; dynamic labels/VAP; rollover; idempotency; membership';
rollback;

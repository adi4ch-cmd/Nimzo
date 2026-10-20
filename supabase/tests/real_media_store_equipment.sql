-- Run as postgres against a disposable migrated database with social_baseline.sql.
-- All fixture catalog/equipment/profile changes are rolled back, never use live DB.
begin;

create temp table store_financial_before as
select 'wallets' as source, coalesce(jsonb_agg(to_jsonb(w) order by w.user_id), '[]'::jsonb) as rows
from public.wallets w
union all
select 'ledger', coalesce(jsonb_agg(to_jsonb(l) order by l.id), '[]'::jsonb)
from public.ledger l;
create temp table store_profiles_before as select * from public.profiles;
create temp table store_legacy_before as
select * from public.nimzo_cosmetic_catalog where id like 'nimzo-original-%';

-- Dedicated fixtures avoid assumptions about which source media is selected.
insert into public.nimzo_cosmetic_catalog(id,category,name,variant,coin_price,active) values
 ('test-store-wave-a','Mic Wave','Test Wave A',0,0,true),
 ('test-store-wave-b','Mic Wave','Test Wave B',0,0,true),
 ('test-store-profile','Profile Card','Test Profile',0,0,true),
 ('test-store-id-frame','ID Frame','Test ID',0,0,true),
 ('test-store-inactive','Avatar Frame','Test Inactive',0,0,false);

set local role anon;
do $$begin
 begin
  perform public.nimzo_store_visual_equipment(array['00000000-0000-4000-8000-000000000101'::uuid]);
  raise exception 'Anonymous visual read succeeded';
 exception when insufficient_privilege then null; end;
 begin
  perform public.nimzo_store_unequip('Mic Wave');
  raise exception 'Anonymous unequip succeeded';
 exception when insufficient_privilege then null; end;
end$$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
do $$begin
 begin
  perform public.nimzo_store_visual_equipment(null);
  raise exception 'Unsigned visual read succeeded';
 exception when sqlstate '28000' then null; end;
 begin
  perform public.nimzo_store_unequip('Mic Wave');
  raise exception 'Unsigned unequip succeeded';
 exception when sqlstate '28000' then null; end;
end$$;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
do $$begin
 begin
  perform public.nimzo_store_equip_free('test-store-wave-a');
  raise exception 'Unowned equip succeeded';
 exception when insufficient_privilege then null; end;
 begin
  perform public.nimzo_store_claim_free('test-store-inactive');
  raise exception 'Inactive item claimed';
 exception when invalid_parameter_value then null; end;
 perform public.nimzo_store_claim_free('test-store-wave-a');
 perform public.nimzo_store_claim_free('test-store-wave-a');
 perform public.nimzo_store_claim_free('test-store-profile');
 perform public.nimzo_store_claim_free('test-store-id-frame');
 perform public.nimzo_store_equip_free('test-store-wave-a');
 perform public.nimzo_store_equip_free('test-store-profile');
 perform public.nimzo_store_equip_free('test-store-id-frame');
 if (select count(*) from public.nimzo_cosmetic_ownership where item_id='test-store-wave-a') <> 1 then
  raise exception 'Repeated claim duplicated ownership'; end if;
 begin
  perform public.nimzo_store_visual_equipment(array_fill(auth.uid(),array[101]));
  raise exception 'Oversized visual request succeeded';
 exception when invalid_parameter_value then null; end;
 perform public.nimzo_store_visual_equipment(array_fill(auth.uid(),array[100]));
 if exists(select 1 from public.nimzo_store_visual_equipment(null))
 or exists(select 1 from public.nimzo_store_visual_equipment('{}'::uuid[])) then
  raise exception 'Empty visual request returned rows'; end if;
 begin
  perform public.nimzo_store_unequip('not a category');
  raise exception 'Invalid unequip category accepted';
 exception when invalid_parameter_value then null; end;
end$$;

-- Another signed-in user can see appearances, but not another user's inventory.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
do $$begin
 if exists(select 1 from public.nimzo_cosmetic_ownership where user_id='00000000-0000-4000-8000-000000000101')
 or exists(select 1 from public.nimzo_cosmetic_equipped where user_id='00000000-0000-4000-8000-000000000101') then
  raise exception 'Cross-user inventory/equipment table read exposed'; end if;
 if (select count(*) from public.nimzo_store_visual_equipment(array[
   '00000000-0000-4000-8000-000000000101'::uuid,
   '00000000-0000-4000-8000-000000000101'::uuid
  ]) where item_id in ('test-store-wave-a','test-store-profile','test-store-id-frame')) <> 3 then
  raise exception 'Cross-user appearance projection missing or duplicated'; end if;
 begin
  perform public.nimzo_store_equip_free('test-store-wave-a');
  raise exception 'Another user ownership authorized equip';
 exception when insufficient_privilege then null; end;
 begin
  update public.nimzo_cosmetic_catalog set category='Royal Badge' where id='test-store-wave-a';
  raise exception 'Client edited authoritative catalog';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.nimzo_cosmetic_equipped where user_id='00000000-0000-4000-8000-000000000101';
  raise exception 'Direct equipped delete allowed';
 exception when insufficient_privilege then null; end;
 perform public.nimzo_store_unequip('Mic Wave');
 if not exists(select 1 from public.nimzo_store_visual_equipment(array[
  '00000000-0000-4000-8000-000000000101'::uuid]) where item_id='test-store-wave-a') then
  raise exception 'Unequip affected another user'; end if;
 perform public.nimzo_store_claim_free('test-store-wave-b');
 perform public.nimzo_store_equip_free('test-store-wave-b');
end$$;
reset role;

-- Catalog retirement and mismatched stored categories must not render publicly.
update public.nimzo_cosmetic_catalog set active=false where id='test-store-wave-b';
update public.nimzo_cosmetic_equipped set category='Rides'
where user_id='00000000-0000-4000-8000-000000000101' and item_id='test-store-id-frame';
set local role authenticated;
do $$begin
 if exists(select 1 from public.nimzo_store_visual_equipment(array[
  '00000000-0000-4000-8000-000000000101'::uuid,
  '00000000-0000-4000-8000-000000000102'::uuid
 ]) where item_id in ('test-store-wave-b','test-store-id-frame')) then
  raise exception 'Retired or category-mismatched appearance exposed'; end if;
end$$;
reset role;
update public.nimzo_cosmetic_equipped set category='ID Frame'
where user_id='00000000-0000-4000-8000-000000000101' and item_id='test-store-id-frame';
update public.nimzo_cosmetic_catalog set active=true where id='test-store-wave-b';
update public.profiles set status='suspended' where id='00000000-0000-4000-8000-000000000102';
set local role authenticated;
do $$begin
 begin
  perform public.nimzo_store_unequip('Mic Wave');
  raise exception 'Suspended caller unequipped';
 exception when insufficient_privilege then null; end;
 begin
  perform public.nimzo_store_visual_equipment(null);
  raise exception 'Suspended caller read appearances';
 exception when insufficient_privilege then null; end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
do $$begin
 if exists(select 1 from public.nimzo_store_visual_equipment(array[
  '00000000-0000-4000-8000-000000000102'::uuid])) then
  raise exception 'Suspended target appearance exposed'; end if;
end$$;
reset role;
update public.profiles set status='active' where id='00000000-0000-4000-8000-000000000102';

-- Reset and restore identity to simulate sign out/sign in: state is in the DB.
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
do $$begin
 if not exists(select 1 from public.nimzo_cosmetic_equipped where item_id='test-store-wave-a') then
  raise exception 'Equipment did not persist across identity reset'; end if;
 perform public.nimzo_store_unequip('Mic Wave');
 perform public.nimzo_store_unequip('Mic Wave');
 if exists(select 1 from public.nimzo_cosmetic_equipped where category='Mic Wave') then
  raise exception 'Unequip did not remove own equipment'; end if;
 if not exists(select 1 from public.nimzo_cosmetic_ownership where item_id='test-store-wave-a') then
  raise exception 'Unequip deleted ownership'; end if;
 if not exists(select 1 from public.nimzo_cosmetic_equipped where item_id='test-store-profile') then
  raise exception 'Unequip changed another category'; end if;
 perform public.nimzo_store_equip_free('test-store-wave-a');
end$$;
reset role;

do $$begin
 if exists (
  (select * from public.profiles except select * from store_profiles_before)
  union all (select * from store_profiles_before except select * from public.profiles)
 ) then raise exception 'Store changed account profiles'; end if;
 if exists (
  (select * from public.nimzo_cosmetic_catalog where id like 'nimzo-original-%' except select * from store_legacy_before)
  union all (select * from store_legacy_before except select * from public.nimzo_cosmetic_catalog where id like 'nimzo-original-%')
 ) then raise exception 'Store changed legacy catalog'; end if;
 if (select rows from store_financial_before where source='wallets') is distinct from
  (select coalesce(jsonb_agg(to_jsonb(w) order by w.user_id),'[]'::jsonb) from public.wallets w)
 or (select rows from store_financial_before where source='ledger') is distinct from
  (select coalesce(jsonb_agg(to_jsonb(l) order by l.id),'[]'::jsonb) from public.ledger l) then
  raise exception 'Store changed wallet or ledger'; end if;
end$$;

rollback;

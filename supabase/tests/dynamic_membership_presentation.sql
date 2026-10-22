-- Run only against an isolated fixture with prospective membership + dynamic
-- revision migrations installed. Every write is rolled back.
begin;
do $$
begin
 if not exists(select 1 from pg_class where oid='public.nimzo_membership_presentations'::regclass and relrowsecurity) then
  raise exception 'presentation RLS required'; end if;
 if has_table_privilege('authenticated','public.nimzo_membership_presentations','INSERT')
 or has_table_privilege('authenticated','public.nimzo_membership_presentations','UPDATE')
 or has_table_privilege('anon','public.nimzo_membership_presentations','SELECT') then
  raise exception 'presentation write/private privileges exposed'; end if;
 if has_column_privilege('authenticated','public.nimzo_membership_presentations','rights_record','SELECT') then
  raise exception 'private provenance exposed'; end if;
end $$;
insert into public.nimzo_membership_presentations(kind,tier,title,source_record,rights_record)
values('vip',1,'VIP 1','fixture','fixture');
do $$
declare initial_revision bigint;
begin
 select revision into initial_revision from public.nimzo_content_revisions where channel='settings';
 update public.nimzo_membership_presentations set title='VIP One' where kind='vip' and tier=1;
 if (select revision from public.nimzo_content_revisions where channel='settings')<>initial_revision+1 then
  raise exception 'presentation did not invalidate settings'; end if;
 if (select version from public.nimzo_membership_presentations where kind='vip' and tier=1)<>2 then
  raise exception 'version did not advance'; end if;
 begin
  update public.nimzo_membership_presentations set approved=true where kind='vip' and tier=1;
  raise exception 'approved without proof';
 exception when check_violation then null; end;
 begin
  update public.nimzo_membership_presentations set benefit_keys=array['moderation_immunity'] where kind='vip' and tier=1;
  raise exception 'unsupported entitlement accepted';
 exception when check_violation then null; end;
 begin
  update public.nimzo_membership_presentations set hero='{"url":"http://unsafe.test/a","bytes":2,"sha256":"x","format":"png"}' where kind='vip' and tier=1;
  raise exception 'unsafe media accepted';
 exception when check_violation then null; end;
end $$;
set local role authenticated;
do $$ begin
 if exists(select 1 from public.nimzo_membership_presentations where kind='vip' and tier=1) then
  raise exception 'inactive staging visible'; end if;
end $$;
reset role;
update public.nimzo_membership_presentations set
 hero=jsonb_build_object('url','https://example.test/'||repeat('a',64)||'.png','bytes',100,'sha256',repeat('a',64),'format','png'),
 badge=jsonb_build_object('url','https://example.test/'||repeat('b',64)||'.png','bytes',100,'sha256',repeat('b',64),'format','png'),
 approved=true,active=true,device_proof_record='fixture proof',benefit_keys=array['badge','daily_reward']
 where kind='vip' and tier=1;
set local role authenticated;
do $$ begin
 if not exists(select 1 from public.nimzo_membership_presentations where kind='vip' and tier=1) then
  raise exception 'approved publication not visible'; end if;
 begin
  update public.nimzo_membership_presentations set tier=10 where kind='vip' and tier=1;
  raise exception 'client can publish';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.nimzo_membership_presentations set active=false where kind='vip' and tier=1;
set local role authenticated;
do $$ begin
 if exists(select 1 from public.nimzo_membership_presentations where kind='vip' and tier=1) then
  raise exception 'deactivation not hidden'; end if;
end $$;
reset role;
rollback;

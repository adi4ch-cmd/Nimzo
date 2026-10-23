-- Disposable fixture only. No production user or financial writes.
begin;
insert into public.nimzo_membership_presentations(kind,tier,title,hero,badge,card,
 source_record,rights_record,device_proof_record,approved,active)
select 'svip',10,'SVIP 10',
 jsonb_build_object('url','https://example.test/'||repeat('a',64)||'.webp',
  'sha256',repeat('a',64),'bytes',100,'format','webp','animation',
  jsonb_build_object('url','https://example.test/'||repeat('b',64)||'.svga',
   'sha256',repeat('b',64),'bytes',200,'format','svga')),
 jsonb_build_object('url','https://example.test/'||repeat('c',64)||'.png',
  'sha256',repeat('c',64),'bytes',100,'format','png'),
 jsonb_build_object('url','https://example.test/'||repeat('d',64)||'.png',
  'sha256',repeat('d',64),'bytes',100,'format','png'),
 'fixture','fixture','fixture',true,true;
do $$
declare bad jsonb;
begin
 foreach bad in array array[
  'null'::jsonb,
  '{"format":"svga"}'::jsonb,
  jsonb_build_object('url','https://example.test/'||repeat('b',64)||'.mp4',
   'sha256',repeat('b',64),'bytes',200,'format','vap'),
  jsonb_build_object('url','http://example.test/'||repeat('b',64)||'.svga',
   'sha256',repeat('b',64),'bytes',200,'format','svga'),
  jsonb_build_object('url','https://example.test/'||repeat('b',64)||'.svga',
   'sha256',repeat('b',64),'bytes',4194305,'format','svga')
 ] loop
  begin
   update public.nimzo_membership_presentations set hero=jsonb_set(hero,'{animation}',bad)
    where kind='svip' and tier=10;
   raise exception 'Unsafe nested animation accepted';
  exception when check_violation then null; end;
 end loop;
 begin
  update public.nimzo_membership_presentations set card=hero->'animation'
   where kind='svip' and tier=10;
  raise exception 'Animated card accepted';
 exception when check_violation then null; end;
 begin
  update public.nimzo_membership_presentations set hero=hero->'animation'
   where kind='svip' and tier=10;
  raise exception 'Old-client static hero fallback removed';
 exception when check_violation then null; end;
end $$;
set local role authenticated;
do $$ begin
 if (select card->>'format' from public.nimzo_membership_presentations
  where kind='svip' and tier=10) is distinct from 'png' then
  raise exception 'Authenticated client cannot read approved card'; end if;
 if has_column_privilege('authenticated','public.nimzo_membership_presentations','source_record','SELECT')
 or has_column_privilege('authenticated','public.nimzo_membership_presentations','card','UPDATE') then
  raise exception 'Presentation privileges widened'; end if;
end $$;
reset role;
rollback;

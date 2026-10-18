begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
insert into storage.objects(bucket_id,name) values('avatars','00000000-0000-4000-8000-000000000102/own.png');
do $$begin
 begin insert into storage.objects(bucket_id,name) values('avatars','00000000-0000-4000-8000-000000000103/foreign.png');raise exception 'Cross-account avatar write allowed';exception when insufficient_privilege then null;end;
 begin update storage.objects set name='00000000-0000-4000-8000-000000000103/moved.png' where name='00000000-0000-4000-8000-000000000102/own.png';raise exception 'Avatar ownership reassigned';exception when insufficient_privilege then null;end;
 begin insert into storage.objects(bucket_id,name) select 'room-images',id::text||'/foreign.png' from public.rooms where owner_id='00000000-0000-4000-8000-000000000101';raise exception 'Cross-owner room image write allowed';exception when insufficient_privilege then null;end;
end$$;
insert into storage.objects(bucket_id,name) values('moment-images','00000000-0000-4000-8000-000000000102/own.png');
reset role;
rollback;

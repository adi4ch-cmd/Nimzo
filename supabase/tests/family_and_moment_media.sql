-- Run only against disposable PostgreSQL with the fixture baseline below.
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',false);
select public.create_family('Nimzo friends','','family_test_001');
select public.create_family('Nimzo friends','','family_test_001');
do $$begin
 begin
 insert into public.nimzo_families(owner_id,name) values(auth.uid(),'Free bypass');
 raise exception 'direct creation bypassed cost';
 exception when insufficient_privilege then null; end;
 begin
 perform public.create_family('Different family','','family_test_001');
 raise exception 'request key payload conflict accepted';
 exception when invalid_parameter_value then null; end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',false);
set role authenticated;
do $$begin
 begin
 perform public.create_family('Cannot afford','','family_test_002');
 raise exception 'insufficient balance accepted';
 exception when check_violation then null; end;
end$$;
insert into public.nimzo_family_members(family_id,user_id) values
 ((select id from public.nimzo_families where owner_id='00000000-0000-4000-8000-000000000101'),auth.uid());
do $$begin
 if (select count(*) from public.nimzo_families)<>1 then raise exception 'directory missing'; end if;
 update public.nimzo_families set name='hijacked' where id=(select id from public.nimzo_families where owner_id='00000000-0000-4000-8000-000000000101');
 if found then raise exception 'non-owner edited family'; end if;
 delete from public.nimzo_family_members where user_id='00000000-0000-4000-8000-000000000101';
 if found then raise exception 'non-owner removed another member'; end if;
 begin
 insert into public.nimzo_family_members(family_id,user_id) values
 ((select id from public.nimzo_families where owner_id='00000000-0000-4000-8000-000000000101'),'00000000-0000-4000-8000-000000000103');
 raise exception 'forged membership accepted';
 exception when insufficient_privilege then null; end;
end$$;
insert into public.moments(author_id,body,image_paths) values
 (auth.uid(),'photos',
 array[auth.uid()::text||'/one.jpg',auth.uid()::text||'/two.jpg']);
do $$begin
 if (select image_path from public.moments where author_id=auth.uid() and body='photos') is distinct from auth.uid()::text||'/one.jpg' then raise exception 'legacy image missing'; end if;
 if jsonb_array_length(public.moments_feed_v2()->0->'image_paths')<>2 then raise exception 'feed lost media'; end if;
 begin
 update public.moments set image_paths=array['another-user/photo.jpg'];
 raise exception 'forged media accepted';
 exception when check_violation then null; end;
 begin
 update public.moments set image_paths=array_fill(auth.uid()::text||'/x.jpg',array[10]);
 raise exception 'too many media accepted';
 exception when check_violation then null; end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',false);
set role authenticated;
do $$begin
 update public.moments set body='hijacked';
 if found then raise exception 'non-author changed moment'; end if;
end$$;
reset role;
set role anon;
do $$begin
 begin
 perform * from public.nimzo_families;
 raise exception 'anonymous directory access';
 exception when insufficient_privilege then null; end;
end$$;
reset role;

do $$begin
 if (select coins from public.wallets where user_id='00000000-0000-4000-8000-000000000101')<>2000000 then raise exception 'charge not exactly 1M once'; end if;
 if (select coins from public.wallets where user_id='00000000-0000-4000-8000-000000000102')<>100 then raise exception 'joining charged coins'; end if;
 if (select count(*) from public.ledger where kind='family_creation')<>1 then raise exception 'duplicate ledger'; end if;
end$$;

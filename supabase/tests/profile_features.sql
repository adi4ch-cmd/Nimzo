-- Run inside a transaction and roll back; these are never production fixtures.
insert into auth.users(id,email) values
('00000000-0000-4000-8000-000000000901','profile-check-a@example.invalid'),
('00000000-0000-4000-8000-000000000902','profile-check-b@example.invalid'),
('00000000-0000-4000-8000-000000000903','profile-check-c@example.invalid');
insert into public.gifts(id,name,category,coin_price,min_vip,min_svip,active)
 values('00000000-0000-4000-8000-000000000904','Transaction-only test gift','classic',1000,0,0,true);
insert into public.profile_collectibles(id,kind,name,image_path)
 values('00000000-0000-4000-8000-000000000905','medal','Transaction-only award','test.svg');
update public.wallets set coins=10000 where user_id='00000000-0000-4000-8000-000000000901';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000901',true);
set local role authenticated;
do $$ begin
 if has_column_privilege('authenticated','public.profiles','vip_level','UPDATE') then raise exception 'protected profile grant changed'; end if;
 begin
  insert into public.profile_owned_collectibles(user_id,collectible_id)
   values(auth.uid(),'00000000-0000-4000-8000-000000000905');
  raise exception 'self award allowed';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.profile_collectibles(kind,name,image_path) values('car','Forgery','bad.svg');
  raise exception 'catalog forgery allowed';
 exception when insufficient_privilege then null; end;
 insert into public.couple_requests(requester_id,addressee_id)
  values(auth.uid(),'00000000-0000-4000-8000-000000000902');
 begin
  perform public.respond_couple_request((select id from public.couple_requests where requester_id=auth.uid()),true);
  raise exception 'requester accepted own invitation';
 exception when raise_exception then if sqlerrm<>'pending invitation not found' then raise; end if; end;
 perform public.record_visit(auth.uid());
 perform public.record_visit('00000000-0000-4000-8000-000000000902');
 perform public.record_visit('00000000-0000-4000-8000-000000000902');
 if public.profile_stats('00000000-0000-4000-8000-000000000902')->>'visitors'<>'2' then raise exception 'total visitor count incorrect'; end if;
 if public.profile_stats(auth.uid())->>'visitors'<>'0' then raise exception 'self visit recorded'; end if;
end $$;
do $$ declare a jsonb; b jsonb; begin
 a:=public.send_profile_gift('00000000-0000-4000-8000-000000000902','00000000-0000-4000-8000-000000000904',2,'profile-test-key');
 if a->>'total'<>'2000' or a->>'diamonds'<>'900' then raise exception 'incorrect gift split'; end if;
 b:=public.send_profile_gift('00000000-0000-4000-8000-000000000902','00000000-0000-4000-8000-000000000904',2,'profile-test-key');
 if b->>'status'<>'replayed' then raise exception 'retry did not replay'; end if;
 begin
  perform public.send_profile_gift('00000000-0000-4000-8000-000000000903','00000000-0000-4000-8000-000000000904',2,'profile-test-key');
  raise exception 'changed retry payload accepted';
 exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise; end if; end;
 begin
  perform public.send_profile_gift('00000000-0000-4000-8000-000000000902','00000000-0000-4000-8000-000000000904',99,'profile-insufficient');
  raise exception 'overdraw accepted';
 exception when raise_exception then if sqlerrm<>'insufficient coins' then raise; end if; end;
 begin
  perform public.send_profile_gift(auth.uid(),'00000000-0000-4000-8000-000000000904',1,'profile-self');
  raise exception 'self profile gift allowed';
 exception when raise_exception then if sqlerrm<>'invalid profile gift' then raise; end if; end;
end $$;
reset role;
do $$ begin
 if (select coins from public.wallets where user_id='00000000-0000-4000-8000-000000000901')<>8000 then raise exception 'sender charged twice'; end if;
 if (select diamonds from public.wallets where user_id='00000000-0000-4000-8000-000000000902')<>900 then raise exception 'receiver credit incorrect'; end if;
 if (select count(*) from public.gift_events where sender_id='00000000-0000-4000-8000-000000000901')<>1 then raise exception 'incorrect event count'; end if;
 if (select count(*) from public.couples where user_a='00000000-0000-4000-8000-000000000901')<>0 then raise exception 'relationship created before consent'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000903',true);
set local role authenticated;
do $$ begin if exists(select 1 from public.couple_requests) then raise exception 'private invitations exposed'; end if; end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000902',true);
set local role authenticated;
select public.respond_couple_request((select id from public.couple_requests where addressee_id=auth.uid()),true);
reset role;
do $$ begin
 if not exists(select 1 from public.couples where user_a='00000000-0000-4000-8000-000000000901' and user_b='00000000-0000-4000-8000-000000000902') then raise exception 'consented couple not linked'; end if;
 if not exists(select 1 from public.couple_requests where status='accepted') then raise exception 'invitation not accepted'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000901',true);
set local role authenticated;
insert into public.couple_requests(requester_id,addressee_id) values(auth.uid(),'00000000-0000-4000-8000-000000000903');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000903',true);
set local role authenticated;
do $$ begin
 begin perform public.respond_couple_request((select id from public.couple_requests where addressee_id=auth.uid()),true);
 raise exception 'second partner accepted';
 exception when raise_exception then if sqlerrm<>'a partner is already linked' then raise; end if; end;
end $$;
reset role;
select 'profile collection authorization, CP consent, gift settlement/replay and visitor assertions passed' as result;

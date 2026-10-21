-- Disposable minimal Postgres database only. Run after loading the migration;
-- public.profiles/ledger/gift_events/rooms and auth.uid() must match used columns.
-- Every fixture and change is rolled back. Never run against production.
begin;
insert into public.profiles(id,display_name,status) values
 ('00000000-0000-0000-0000-000000000001','First','active'),
 ('00000000-0000-0000-0000-000000000002','Second','active');
insert into public.ledger(user_id,kind,coin_delta,diamond_delta,created_at) values
 ('00000000-0000-0000-0000-000000000001','gift_sent',-100,0,now()-interval '1 hour'),
 ('00000000-0000-0000-0000-000000000001','profile_gift_sent',-200,0,now()-interval '2 days'),
 ('00000000-0000-0000-0000-000000000001','moment_gift_sent',-400,0,now()-interval '10 days'),
 ('00000000-0000-0000-0000-000000000001','gift_sent',-800,0,now()-interval '40 days'),
 ('00000000-0000-0000-0000-000000000001','gift_received',0,45,now()-interval '1 hour'),
 ('00000000-0000-0000-0000-000000000001','profile_gift_received',0,90,now()-interval '2 days'),
 ('00000000-0000-0000-0000-000000000001','moment_gift_received',0,180,now()-interval '10 days'),
 ('00000000-0000-0000-0000-000000000001','self_gift_45pct_adjustment',0,360,now()-interval '40 days'),
 ('00000000-0000-0000-0000-000000000001','topup',-99999,99999,now()),
 ('00000000-0000-0000-0000-000000000001','gift_sent',-99999,0,now()+interval '1 day'),
 ('00000000-0000-0000-0000-000000000002','gift_sent',-100,0,now()-interval '1 hour');
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
set local role authenticated;
do $$
declare periods text[]:=array['daily','weekly','monthly','all_time'];
        sent bigint[]:=array[100,300,700,1500];
        received bigint[]:=array[45,135,315,675];
        i integer;
begin
 for i in 1..4 loop
  if (select score from public.leaderboard('wealth',periods[i],100) where id=auth.uid()) is distinct from sent[i] then raise exception 'wrong Wealth %',periods[i]; end if;
  if (select score from public.leaderboard('charm',periods[i],100) where id=auth.uid()) is distinct from received[i] then raise exception 'wrong Charm %',periods[i]; end if;
 end loop;
 if (select id from public.leaderboard('wealth','daily',1))<>auth.uid() then raise exception 'unstable tied rank or invalid limit'; end if;
 if (select count(*) from public.leaderboard('wealth','daily',null))<>2 then raise exception 'null limit missing default'; end if;
 begin perform public.leaderboard('wealth','yearly',10); raise exception 'accepted invalid period'; exception when invalid_parameter_value then null; end;
 begin perform public.leaderboard(null,'daily',10); raise exception 'accepted null kind'; exception when invalid_parameter_value then null; end;
 begin perform public.leaderboard('wealth','daily',0); raise exception 'accepted zero limit'; exception when invalid_parameter_value then null; end;
 begin perform public.leaderboard('wealth','daily',101); raise exception 'accepted oversized limit'; exception when invalid_parameter_value then null; end;
end $$;
set local request.jwt.claim.sub='';
do $$ begin
 begin perform public.leaderboard('wealth','daily',10); raise exception 'accepted unauthenticated call'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;
do $$ begin
 if has_function_privilege('anon','public.leaderboard(text,text,integer)','EXECUTE') then raise exception 'anonymous execute exposed'; end if;
end $$;
select 'PASS ranking periods, actual settled totals, stable ties, bounds and auth' as result;
rollback;

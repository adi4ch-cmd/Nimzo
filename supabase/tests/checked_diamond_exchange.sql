begin;
insert into profiles(id) values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
insert into wallets(user_id,coins,diamonds) select id,1000,2000 from profiles;
do $$declare r jsonb;begin
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 r:=public.exchange_diamonds_checked(100,'confirmed-exchange',auth.uid());
 if r->>'status'<>'exchanged' or r->>'amount'<>'100' then raise exception 'Unconfirmed conversion';end if;
 if (select coins from wallets where user_id=auth.uid())<>1100 or (select diamonds from wallets where user_id=auth.uid())<>1900 then raise exception 'Rate changed';end if;
 -- Recover a settled receipt even when mutable account status later changes.
 update profiles set status='restricted' where id=auth.uid();
 r:=public.exchange_diamonds_checked(100,'confirmed-exchange',auth.uid());
 if r->>'status'<>'replayed' or (select count(*) from ledger)<>1 then raise exception 'Conversion replay changed funds';end if;
 begin perform public.exchange_diamonds_checked(200,'confirmed-exchange',auth.uid());raise exception 'Changed amount accepted';exception when sqlstate '22023' then null;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 begin perform public.exchange_diamonds_checked(100,'switched','00000000-0000-0000-0000-000000000001');raise exception 'Switched account debit';exception when sqlstate '22023' then null;end;
 begin perform public.exchange_diamonds_checked(2001,'insufficient',auth.uid());raise exception 'Exchanged unowned diamonds';exception when sqlstate 'P0001' then if sqlerrm<>'insufficient diamonds' then raise;end if;end;
 if (select sum(coins+diamonds) from wallets)<>6000 or (select count(*) from ledger)<>1 then raise exception 'Conversion conservation failed';end if;
 if has_function_privilege('anon','public.exchange_diamonds_checked(bigint,text,uuid)','execute') then raise exception 'Anonymous exchange grant';end if;
end$$;
rollback;

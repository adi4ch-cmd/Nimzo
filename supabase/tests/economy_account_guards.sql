begin;
update public.profiles set status='suspended' where id='00000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000102',true);
do $$begin
 begin perform public.exchange_diamonds(1,'restricted-exchange');raise exception 'Suspended account exchanged funds' using errcode='XX000';exception when insufficient_privilege then null;end;
end$$;
reset role;
update public.profiles set status='active' where id='00000000-0000-4000-8000-000000000102';
insert into public.resellers(user_id,coin_limit) values('00000000-0000-4000-8000-000000000101',10000);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
select public.reseller_recharge('00000000-0000-4000-8000-000000000103',500,'reseller-fixture');
select public.reseller_recharge('00000000-0000-4000-8000-000000000103',500,'reseller-fixture');
do $$begin
 begin perform public.reseller_recharge('00000000-0000-4000-8000-000000000103',1000,'reseller-fixture');raise exception 'Changed reseller amount accepted' using errcode='XX000';exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise;end if;end;
 begin perform public.reseller_recharge('00000000-0000-4000-8000-000000000102',500,'reseller-fixture');raise exception 'Changed reseller recipient accepted' using errcode='XX000';exception when raise_exception then if sqlerrm<>'idempotency payload mismatch' then raise;end if;end;
end$$;
reset role;
do $$begin if (select coin_limit from public.resellers where user_id='00000000-0000-4000-8000-000000000101')<>9500 then raise exception 'Reseller charged twice';end if;end$$;
rollback;

-- Disposable restored-membership fixture only; never production. All writes rollback.
begin;
insert into public.profiles(id,display_name) values('00000000-0000-4000-8000-000000000911','Checked VIP fixture');
insert into public.wallets(user_id,coins,diamonds) values('00000000-0000-4000-8000-000000000911',2000000000,321);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000911',true);
set local role authenticated;
do $$ declare price bigint; a jsonb; begin
 select coin_price into price from public.normal_vip_catalog where tier=1;
 begin
  perform public.nimzo_purchase_vip_checked(1,'checked-wrong-price',price+1);
  raise exception 'Mismatched price accepted';
 exception when invalid_parameter_value then null; end;
 a:=public.nimzo_purchase_vip_checked(1,'checked-stable-replay',price);
 if a->>'status'<>'ok' then raise exception 'Checked purchase not confirmed'; end if;
end $$;
reset role;
-- Change actual catalog and restrict account AFTER settlement; recovery must
-- find the committed receipt before checking current price/eligibility.
update public.normal_vip_catalog set coin_price=coin_price+100 where tier=1;
update public.profiles set status='banned' where id=auth.uid();
set local role authenticated;
do $$ declare a jsonb; begin
 begin
  perform public.nimzo_purchase_vip_checked(1,'checked-stable-replay',0);
  raise exception 'Replay price mismatch accepted';
 exception when invalid_parameter_value then null; end;
 a:=public.nimzo_purchase_vip_checked(1,'checked-stable-replay',(select coin_price-100 from public.normal_vip_catalog where tier=1));
 if a->>'status'<>'replayed' then raise exception 'Lost-response recovery failed'; end if;
 begin
  perform public.nimzo_purchase_vip_checked(2,'checked-stable-replay',0);
  raise exception 'Cross-tier key replay accepted';
 exception when raise_exception then
  if sqlerrm<>'Purchase idempotency payload mismatch' then raise; end if;
 end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.ledger where user_id=auth.uid() and kind='vip_purchase')<>1 then
  raise exception 'Replay charged twice'; end if;
 if (select diamonds from public.wallets where user_id=auth.uid())<>321 then
  raise exception 'Diamonds changed'; end if;
 if exists(select 1 from public.ledger where user_id=auth.uid() and idempotency_key='vip:checked-wrong-price') then
  raise exception 'Rejected price wrote ledger'; end if;
end $$;
rollback;

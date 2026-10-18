begin;
-- Even a configured amount cannot award coins while its switch is disabled.
insert into public.economy_settings(setting_key,numeric_value,active)
values ('daily_checkin_reward_coins',100,false)
on conflict (setting_key) do update set numeric_value=100,active=false;
select set_config('test.wallet_before',(select coins::text from public.wallets where user_id='00000000-0000-4000-8000-000000000101'),true);
select set_config('test.ledger_before',(select count(*)::text from public.ledger),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',true);
do $$begin
 begin
 perform public.claim_daily_checkin();
 raise exception 'Disabled reward unexpectedly succeeded' using errcode='XX000';
 exception when sqlstate 'P0001' then
 if sqlerrm <> 'Daily reward is not configured' then raise; end if;
 end;
 begin
 insert into public.daily_checkins(user_id,day_utc,coins_awarded)
 values (auth.uid(),current_date,100);
 raise exception 'Direct reward bypass allowed';
 exception when insufficient_privilege then null;
 end;
end$$;
reset role;
do $$begin
 if (select coins from public.wallets where user_id='00000000-0000-4000-8000-000000000101') <> current_setting('test.wallet_before')::bigint
 or (select count(*) from public.ledger) <> current_setting('test.ledger_before')::bigint then
 raise exception 'Disabled reward changed wallet or ledger'; end if;
end$$;
rollback;

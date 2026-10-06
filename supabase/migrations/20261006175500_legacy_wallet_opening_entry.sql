-- Record the observed legacy opening balance without crediting or debiting a wallet.
-- Its original source is not recoverable from retained ledger rows; do not invent a purchase.
do $$
declare u uuid; w bigint; d bigint; total bigint; inserted integer;
begin
 select p.id,wa.coins,wa.diamonds into u,w,d from profiles p join wallets wa on wa.user_id=p.id where p.nimzo_id=100005 for update of wa;
 if u is null then return; end if;
 select coalesce(sum(coin_delta),0) into total from ledger where user_id=u;
 if w-total=0 then return; end if;
 if w-total<>5000000 then raise exception 'legacy opening difference changed: review before reconciliation'; end if;
 insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
 values(u,'legacy_opening_balance',5000000,0,jsonb_build_object('reason','Observed balance carried into audited ledger; original source unavailable','wallet_coins_observed',w,'ledger_coins_before',total,'wallet_changed',false),'legacy-opening-100005-2026-10-06') on conflict do nothing;
 get diagnostics inserted=row_count;
 if inserted=1 then
  insert into audit_logs(actor_id,action,target_type,target_id,before_data,after_data) values(null,'record_legacy_opening_balance','wallet',u::text,jsonb_build_object('coins',w,'diamonds',d,'ledger_coins',total),jsonb_build_object('coins',w,'diamonds',d,'ledger_coins',total+5000000,'wallet_changed',false));
 end if;
 if (select coins from wallets where user_id=u)<>w or (select diamonds from wallets where user_id=u)<>d then raise exception 'wallet unexpectedly changed'; end if;
 if (select coalesce(sum(coin_delta),0) from ledger where user_id=u)<>w then raise exception 'reconciliation failed'; end if;
end $$;

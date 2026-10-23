-- Preserve the original rate/settlement while binding the confirming account.
begin;
create function public.exchange_diamonds_checked(p_amount bigint,p_key text,p_expected_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); prior public.ledger;
begin
 if u is null then raise exception 'AUTH_REQUIRED' using errcode='28000';end if;
 if p_expected_user is distinct from u then raise exception 'EXCHANGE_ACCOUNT_CHANGED' using errcode='22023';end if;
 if p_amount is null or p_amount<=0 or nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'INVALID_EXCHANGE' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('diamond_exchange:'||u::text||':'||p_key,0));
 select * into prior from public.ledger where user_id=u and kind='exchange' and idempotency_key=p_key;
 if found then
  if prior.ref->>'amount' is distinct from p_amount::text or prior.coin_delta is distinct from p_amount or prior.diamond_delta is distinct from -p_amount then raise exception 'EXCHANGE_PAYLOAD_MISMATCH' using errcode='22023';end if;
  return jsonb_build_object('status','replayed','amount',p_amount);
 end if;
 perform public.exchange_diamonds(p_amount,p_key);
 return jsonb_build_object('status','exchanged','amount',p_amount);
end$$;
revoke all on function public.exchange_diamonds_checked(bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.exchange_diamonds_checked(bigint,text,uuid) to authenticated;
notify pgrst,'reload schema';
commit;

-- Read-only production-safe checks for verified gift broadcasts.
do $$
declare v_def text;
begin
 select pg_get_functiondef('public.record_verified_gift_animation()'::regprocedure)
 into v_def;
 if position('v_price < 1000000' in v_def)>0 then
   raise exception 'Small gifts still excluded from verified animation stream';
 end if;
 if position('on conflict (gift_event_id) do nothing' in lower(v_def))=0 then
   raise exception 'Idempotency guard missing from gift animation trigger';
 end if;
 if position('new.total_coins / new.quantity' in v_def)=0 then
   raise exception 'Gift animation price must come from settled total';
 end if;
end $$;

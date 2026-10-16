-- All settled gift scopes use the 45% diamond credit, including self.
-- Room/Moment RPCs already have this policy; enable it for Profile gifts too.
CREATE OR REPLACE FUNCTION nimzo_private.send_profile_gift(p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s uuid:=auth.uid(); g public.gifts%rowtype; pr public.profiles%rowtype;
 total bigint; credit bigint; old_ref jsonb;
begin
 if s is null then raise exception 'not authenticated'; end if;
 if p_receiver is null or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999
  then raise exception 'invalid profile gift'; end if;
 if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'idempotency key required'; end if;
 -- Serialize the same sender/key even if concurrent retries change recipients.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(s::text||':'||p_key,0));
 select ref into old_ref from public.ledger where user_id=s and idempotency_key=p_key||':sender';
 if found then
  if old_ref->>'profile' is distinct from p_receiver::text or old_ref->>'gift' is distinct from p_gift::text
   or old_ref->>'qty' is distinct from p_qty::text then raise exception 'idempotency payload mismatch'; end if;
  return jsonb_build_object('status','replayed');
 end if;
 select * into pr from public.profiles where id=s and status='active';
 if not found then raise exception 'account restricted'; end if;
 if not exists(select 1 from public.profiles where id=p_receiver and status='active') then raise exception 'receiver unavailable'; end if;
 if exists(select 1 from public.blocks where (blocker_id=s and blocked_id=p_receiver)
  or(blocker_id=p_receiver and blocked_id=s)) then raise exception 'gift unavailable'; end if;
 select * into g from public.gifts where id=p_gift and active;
 if not found then raise exception 'gift unavailable'; end if;
 if (case when pr.vip_expires_at>now() then coalesce(pr.vip_level,0) else 0 end)<coalesce(g.min_vip,0)
  or (case when pr.svip_cycle_start+interval '90 days'>now() then coalesce(pr.svip_level,0) else 0 end)<coalesce(g.min_svip,0)
  then raise exception 'gift tier required'; end if;
 total:=g.coin_price*p_qty; credit:=total*45/100;
 perform 1 from public.wallets where user_id in(s,p_receiver) order by user_id for update;
 if (select count(*) from public.wallets where user_id in(s,p_receiver))<>2 then raise exception 'wallet unavailable'; end if;
 update public.wallets set coins=coins-total where user_id=s and coins>=total;
 if not found then raise exception 'insufficient coins'; end if;
 update public.wallets set diamonds=diamonds+credit where user_id=p_receiver;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
 (s,'profile_gift_sent',-total,0,jsonb_build_object('profile',p_receiver,'gift',p_gift,'qty',p_qty),p_key||':sender'),
 (p_receiver,'profile_gift_received',0,credit,jsonb_build_object('profile',p_receiver,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
 insert into public.gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
 values(null,s,p_receiver,p_gift,p_qty,total);
 return jsonb_build_object('status','ok','total',total,'diamonds',credit);
end $function$

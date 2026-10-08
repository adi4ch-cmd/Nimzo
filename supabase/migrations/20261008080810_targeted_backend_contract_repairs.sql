-- Targeted repair against live metadata verified 2026-10-08.
-- Stage/test before deployment. This task never applies SQL to production.
-- No tables, accounts, IDs, balances, catalogs or historical rows are changed.
-- Existing signatures/permissions/45% receiver and 5% room rates remain.
-- vip_status adds server-derived progress fields without changing membership levels.
-- Gift retries bind to their exact payload and serialize before ledger lookup.
-- Charm ignores self-gifts because their actual diamond settlement is zero.
-- Daily remains unsupported instead of silently returning weekly data.

CREATE OR REPLACE FUNCTION public.send_gift(p_room uuid, p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare s uuid:=auth.uid(); owner uuid; allow_g boolean; price bigint; total bigint; diamond_credit bigint; room_credit bigint; mv int; ms int; pr profiles%rowtype; old_ref jsonb;
begin
if s is null then raise exception 'not authenticated'; end if;
if p_receiver is null or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999 then raise exception 'invalid gift request'; end if;
if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'idempotency key required'; end if;
-- Serialize retries before testing the sender ledger, without changing settlement.
perform pg_advisory_xact_lock(hashtextextended('gift_sent:'||s::text||':'||p_key,0));
select ref into old_ref from ledger where user_id=s and idempotency_key=p_key||':sender' and kind='gift_sent';
if found then
 if old_ref->>'room' is distinct from p_room::text
  or old_ref->>'receiver' is distinct from p_receiver::text
  or old_ref->>'gift' is distinct from p_gift::text
  or old_ref->>'qty' is distinct from p_qty::text then
  raise exception 'idempotency payload mismatch';
 end if;
 return jsonb_build_object('status','replayed');
end if;
select owner_id,perm_gift into owner,allow_g from rooms where id=p_room and status='open';
if owner is null or not allow_g then raise exception 'room unavailable or gifts disabled'; end if;
if not exists(select 1 from room_members where room_id=p_room and user_id=s) or not exists(select 1 from room_members where room_id=p_room and user_id=p_receiver) then raise exception 'room member required'; end if;
select * into pr from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
select coin_price,min_vip,min_svip into price,mv,ms from gifts where id=p_gift and active; if price is null then raise exception 'gift unavailable'; end if;
if (case when pr.vip_expires_at>now() then coalesce(pr.vip_level,0) else 0 end)<coalesce(mv,0) or (case when pr.svip_cycle_start+interval '90 days'>now() then coalesce(pr.svip_level,0) else 0 end)<coalesce(ms,0) then raise exception 'gift tier required'; end if;
if exists(select 1 from room_bans where room_id=p_room and user_id in(s,p_receiver)) then raise exception 'banned from room'; end if;
if not room_allows(p_room,s,(select gift_permission from rooms where id=p_room)) then raise exception 'gift permission required'; end if;
total:=price*p_qty; diamond_credit:=case when s=p_receiver then 0 else total*45/100 end; room_credit:=total*5/100;
perform 1 from wallets where user_id in(s,p_receiver,owner) order by user_id for update;
update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;
if owner<>s then update wallets set coins=coins+room_credit where user_id=owner; end if;
insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(s,'gift_sent',-total,0,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty,'receiver',p_receiver),p_key||':sender'),
(p_receiver,'gift_received',0,diamond_credit,jsonb_build_object('room',p_room,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
if owner<>s then insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(owner,'room_reward',room_credit,0,jsonb_build_object('room',p_room,'rate',5),p_key||':room'); end if;
insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(p_room,s,p_receiver,p_gift,p_qty,total);
return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit,'room_coins',room_credit);
end $function$;

CREATE OR REPLACE FUNCTION public.send_moment_gift(p_moment uuid, p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare s uuid:=auth.uid(); price bigint; total bigint; diamond_credit bigint; vip int; svip int; g gifts%rowtype; old_ref jsonb;
begin
if s is null then raise exception 'not authenticated'; end if;
if p_receiver is null or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999 then raise exception 'invalid gift request'; end if;
if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'idempotency key required'; end if;
-- Serialize retries before testing the sender ledger, without changing settlement.
perform pg_advisory_xact_lock(hashtextextended('moment_gift_sent:'||s::text||':'||p_key,0));
select ref into old_ref from ledger where user_id=s and idempotency_key=p_key||':sender' and kind='moment_gift_sent';
if found then
 if old_ref->>'moment' is distinct from p_moment::text
  or old_ref->>'receiver' is distinct from p_receiver::text
  or old_ref->>'gift' is distinct from p_gift::text
  or old_ref->>'qty' is distinct from p_qty::text then
  raise exception 'idempotency payload mismatch';
 end if;
 return jsonb_build_object('status','replayed');
end if;
if not exists(select 1 from moments where id=p_moment and author_id=p_receiver) then raise exception 'moment receiver mismatch'; end if;
select * into g from gifts where id=p_gift and active; if not found then raise exception 'gift unavailable'; end if;
select case when vip_expires_at>now() then vip_level else 0 end,case when svip_cycle_start+interval '90 days'>now() then svip_level else 0 end into vip,svip from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
if vip<g.min_vip or svip<g.min_svip then raise exception 'gift tier required'; end if;
price:=g.coin_price; total:=price*p_qty; diamond_credit:=case when s=p_receiver then 0 else total*45/100 end;
perform 1 from wallets where user_id in(s,p_receiver) order by user_id for update;
update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;
insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(s,'moment_gift_sent',-total,0,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty,'receiver',p_receiver),p_key||':sender'),
(p_receiver,'moment_gift_received',0,diamond_credit,jsonb_build_object('moment',p_moment,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(null,s,p_receiver,p_gift,p_qty,total);
update moments set lifetime_gift_coins=lifetime_gift_coins+total where id=p_moment;
return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit);
end $function$;

CREATE OR REPLACE FUNCTION public.leaderboard(p_kind text, p_period text, p_limit integer DEFAULT 10)
 RETURNS TABLE(id uuid, name text, score bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare since timestamptz:=case p_period when'monthly'then now()-interval'30 days' else now()-interval'7 days' end; begin if p_period is null or p_period not in ('weekly','monthly') then raise exception 'unsupported ranking period'; end if; p_limit:=least(greatest(p_limit,1),100); if p_kind='charm' then return query select p.id,p.display_name,sum(g.total_coins*45/100)::bigint from gift_events g join profiles p on p.id=g.receiver_id where g.created_at>=since and g.sender_id<>g.receiver_id group by p.id order by 3 desc limit p_limit; elsif p_kind='wealth' then return query select p.id,p.display_name,sum(g.total_coins)::bigint from gift_events g join profiles p on p.id=g.sender_id where g.created_at>=since group by p.id order by 3 desc limit p_limit; elsif p_kind='room' then return query select r.id,r.name,sum(g.total_coins)::bigint from gift_events g join rooms r on r.id=g.room_id where g.created_at>=since group by r.id order by 3 desc limit p_limit; else raise exception'bad kind'; end if; end $function$;

-- Preserve membership decisions; expose current-cycle progress using the same
-- authoritative server expiry condition instead of stale profile totals.
create or replace function public.vip_status()
returns jsonb language sql stable security definer set search_path to 'public'
as $function$
 select jsonb_build_object(
   'vip_level', case when vip_expires_at > now() then vip_level else 0 end,
   'vip_expires_at', vip_expires_at,
   'svip_level', case when svip_cycle_start is not null
     and svip_cycle_start + interval '90 days' > now() then svip_level else 0 end,
   'svip_cycle_active', svip_cycle_start is not null
     and svip_cycle_start + interval '90 days' > now(),
   'svip_cycle_cents', case when svip_cycle_start is not null
     and svip_cycle_start + interval '90 days' <= now() then 0 else svip_cycle_cents end
 ) from profiles where id = auth.uid()
$function$;

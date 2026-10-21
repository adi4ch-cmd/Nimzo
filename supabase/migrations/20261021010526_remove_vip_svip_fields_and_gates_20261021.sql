-- Exact live Supabase migration version 20261021010526.
-- Final retirement of *legacy* VIP/SVIP, after 20261016 retirement and
-- 20261021 archival. Preserves accounts, balances, ledger and gift transactions.
-- Refreshed function bodies below are taken from verified live NIMZO deployment.
BEGIN;
CREATE SCHEMA IF NOT EXISTS nimzo_private;
REVOKE ALL ON SCHEMA nimzo_private FROM PUBLIC,anon,authenticated;

-- Private backup of old entitlements, before dropping legacy columns.
CREATE TABLE IF NOT EXISTS nimzo_private.membership_cleanup_snapshot_20261021 AS
 SELECT id,vip_level,vip_expires_at,vip_last_claim,svip_level,svip_cycle_start,
        svip_cycle_cents,svip_last_claim FROM public.profiles;
REVOKE ALL ON nimzo_private.membership_cleanup_snapshot_20261021 FROM PUBLIC,anon,authenticated;
ALTER TABLE nimzo_private.membership_cleanup_snapshot_20261021 ENABLE ROW LEVEL SECURITY;
CREATE TABLE IF NOT EXISTS nimzo_private.membership_function_cleanup_backup_20261021(
 signature text PRIMARY KEY,definition text NOT NULL,captured_at timestamptz NOT NULL DEFAULT now());
REVOKE ALL ON nimzo_private.membership_function_cleanup_backup_20261021 FROM PUBLIC,anon,authenticated;
ALTER TABLE nimzo_private.membership_function_cleanup_backup_20261021 ENABLE ROW LEVEL SECURITY;
INSERT INTO nimzo_private.membership_function_cleanup_backup_20261021(signature,definition)
 SELECT p.oid::regprocedure::text,pg_get_functiondef(p.oid)
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname||'.'||p.proname) IN (
  'public.send_gift','public.send_moment_gift',
  'nimzo_private.send_profile_gift','public.kick_member','public.moderate_room_member')
 ON CONFLICT DO NOTHING;

-- Old membership catalogs remain in the inaccessible private archive.
DO $archive_old$ DECLARE name text;
BEGIN
 FOREACH name IN ARRAY ARRAY['normal_vip_catalog','svip_thresholds','vip_daily_rewards','svip_friday_rewards'] LOOP
  IF to_regclass('public.'||name) IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.%I SET SCHEMA nimzo_private',name);
  END IF;
  IF to_regclass('nimzo_private.'||name) IS NOT NULL THEN
    EXECUTE format('REVOKE ALL ON nimzo_private.%I FROM PUBLIC,anon,authenticated',name);
  END IF;
 END LOOP;
END $archive_old$;
DROP FUNCTION IF EXISTS public.purchase_normal_vip(integer,text);
DROP FUNCTION IF EXISTS public.claim_vip_daily();
DROP FUNCTION IF EXISTS public.claim_svip_friday();
DROP FUNCTION IF EXISTS public.activate_vip(uuid,integer);
DROP FUNCTION IF EXISTS public.vip_status();
DROP FUNCTION IF EXISTS public.phoenix_membership(uuid);
DROP FUNCTION IF EXISTS nimzo_private.pay_svip_sunday_rewards();
DROP FUNCTION IF EXISTS nimzo_private.phoenix_room_entry();

-- Retain the original room permissions, anti-replay, ledger/coin arithmetic
-- and moderation security. Only the old tier gating is removed.
CREATE OR REPLACE FUNCTION public.send_gift(p_room uuid, p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare s uuid:=auth.uid(); owner uuid; allow_g boolean; price bigint; total bigint; diamond_credit bigint; room_credit bigint; old_ref jsonb;
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
perform 1 from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
select coin_price into price from gifts where id=p_gift and active; if price is null then raise exception 'gift unavailable'; end if;
if exists(select 1 from room_bans where room_id=p_room and user_id in(s,p_receiver)) then raise exception 'banned from room'; end if;
if not room_allows(p_room,s,(select gift_permission from rooms where id=p_room)) then raise exception 'gift permission required'; end if;
total:=price*p_qty; diamond_credit:=total*45/100; room_credit:=total*5/100;
perform 1 from wallets where user_id in(s,p_receiver,owner) order by user_id for update;
update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver;
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
declare s uuid:=auth.uid(); price bigint; total bigint; diamond_credit bigint; g gifts%rowtype; old_ref jsonb;
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
perform 1 from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
price:=g.coin_price; total:=price*p_qty; diamond_credit:=total*45/100;
perform 1 from wallets where user_id in(s,p_receiver) order by user_id for update;
update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver;
insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(s,'moment_gift_sent',-total,0,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty,'receiver',p_receiver),p_key||':sender'),
(p_receiver,'moment_gift_received',0,diamond_credit,jsonb_build_object('moment',p_moment,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(null,s,p_receiver,p_gift,p_qty,total);
update moments set lifetime_gift_coins=lifetime_gift_coins+total where id=p_moment;
return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit);
end $function$;

CREATE OR REPLACE FUNCTION nimzo_private.send_profile_gift(p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s uuid:=auth.uid(); g public.gifts%rowtype;
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
 perform 1 from public.profiles where id=s and status='active';
 if not found then raise exception 'account restricted'; end if;
 if not exists(select 1 from public.profiles where id=p_receiver and status='active') then raise exception 'receiver unavailable'; end if;
 if exists(select 1 from public.blocks where (blocker_id=s and blocked_id=p_receiver)
  or(blocker_id=p_receiver and blocked_id=s)) then raise exception 'gift unavailable'; end if;
 select * into g from public.gifts where id=p_gift and active;
 if not found then raise exception 'gift unavailable'; end if;
  total:=g.coin_price*p_qty; credit:=total*45/100;
 perform 1 from public.wallets where user_id in(s,p_receiver) order by user_id for update;
 if (select count(*) from public.wallets where user_id in(s,p_receiver))<>(case when s=p_receiver then 1 else 2 end) then raise exception 'wallet unavailable'; end if;
 update public.wallets set coins=coins-total where user_id=s and coins>=total;
 if not found then raise exception 'insufficient coins'; end if;
 update public.wallets set diamonds=diamonds+credit where user_id=p_receiver;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
 (s,'profile_gift_sent',-total,0,jsonb_build_object('profile',p_receiver,'gift',p_gift,'qty',p_qty),p_key||':sender'),
 (p_receiver,'profile_gift_received',0,credit,jsonb_build_object('profile',p_receiver,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
 insert into public.gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
 values(null,s,p_receiver,p_gift,p_qty,total);
 return jsonb_build_object('status','ok','total',total,'diamonds',credit);
end $function$;

CREATE OR REPLACE FUNCTION public.kick_member(p_room uuid, p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ begin if not can_moderate(p_room,auth.uid()) then raise exception 'not allowed'; end if;  if exists(select 1 from rooms where id=p_room and owner_id=p_user) then raise exception 'cannot kick owner'; end if; update mic_seats set user_id=null where room_id=p_room and user_id=p_user; delete from room_members where room_id=p_room and user_id=p_user; insert into room_bans(room_id,user_id) values(p_room,p_user) on conflict do nothing; end $function$;

CREATE OR REPLACE FUNCTION public.moderate_room_member(p_room uuid, p_user uuid, p_ban boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=auth.uid();
begin
 if actor is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_room is null or p_user is null or p_ban is null then raise exception 'invalid moderation action' using errcode='22023'; end if;
 -- Lock the room before authorization to serialize against room ownership changes.
 perform 1 from public.rooms where id=p_room for update;
 if not found or not public.can_moderate(p_room,actor) then raise exception 'not allowed' using errcode='42501'; end if;
 if exists(select 1 from public.rooms where id=p_room and owner_id=p_user) then raise exception 'cannot kick owner' using errcode='42501'; end if;
 perform 1 from public.profiles where id=p_user for update;
 if not found then raise exception 'member unavailable' using errcode='22023'; end if;
 
 update public.mic_seats set user_id=null where room_id=p_room and user_id=p_user;
 delete from public.room_members where room_id=p_room and user_id=p_user;
 if p_ban then insert into public.room_bans(room_id,user_id) values(p_room,p_user) on conflict do nothing; end if;
end $function$;

DROP TRIGGER IF EXISTS reject_retired_membership ON public.profiles;
DROP FUNCTION IF EXISTS nimzo_private.reject_retired_membership();
ALTER TABLE public.profiles DROP COLUMN IF EXISTS vip_level, DROP COLUMN IF EXISTS vip_expires_at,
 DROP COLUMN IF EXISTS vip_last_claim, DROP COLUMN IF EXISTS svip_level,
 DROP COLUMN IF EXISTS svip_cycle_start, DROP COLUMN IF EXISTS svip_cycle_cents,
 DROP COLUMN IF EXISTS svip_last_claim;
ALTER TABLE public.gifts DROP COLUMN IF EXISTS min_vip, DROP COLUMN IF EXISTS min_svip;
NOTIFY pgrst,'reload schema';
COMMIT;

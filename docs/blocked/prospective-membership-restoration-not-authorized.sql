-- Prospective restoration of the previously approved membership contracts.
-- Does not restore historical profile snapshots or alter balances/catalog prices.
BEGIN;
SET LOCAL lock_timeout='10s';
-- Clients retain only the existing editable profile columns. Refuse activation
-- if membership fields became client-writable after the audited baseline.
DO $guard$
BEGIN
 IF pg_catalog.has_column_privilege('authenticated','public.profiles','vip_level','UPDATE')
 OR pg_catalog.has_column_privilege('authenticated','public.profiles','svip_level','UPDATE')
 OR pg_catalog.has_column_privilege('authenticated','public.profiles','svip_cycle_cents','UPDATE')
 OR pg_catalog.has_column_privilege('authenticated','public.profiles','svip_cycle_start','UPDATE')
 OR pg_catalog.has_column_privilege('authenticated','public.profiles','vip_expires_at','UPDATE')
 OR pg_catalog.has_column_privilege('authenticated','public.profiles','vip_last_claim','UPDATE')
 OR pg_catalog.has_column_privilege('authenticated','public.profiles','svip_last_claim','UPDATE')
 OR pg_catalog.has_table_privilege('authenticated','public.profiles','INSERT') THEN
   RAISE EXCEPTION 'Membership profile columns must remain server-only';
 END IF;
 IF (SELECT count(*) FROM public.normal_vip_catalog WHERE tier BETWEEN 1 AND 10)<>10
 OR (SELECT count(*) FROM public.svip_thresholds WHERE level BETWEEN 1 AND 10)<>10
 OR (SELECT count(*) FROM public.vip_daily_rewards WHERE level BETWEEN 1 AND 10 AND coins>0)<>10
 OR (SELECT count(*) FROM public.svip_friday_rewards WHERE level BETWEEN 1 AND 10 AND coins>0)<>10
 OR (SELECT usd_cents FROM public.svip_thresholds WHERE level=1) IS DISTINCT FROM 5000 THEN
   RAISE EXCEPTION 'Approved membership catalogs missing or inconsistent';
 END IF;
END;
$guard$;
DROP TRIGGER IF EXISTS reject_retired_membership ON public.profiles;

CREATE OR REPLACE FUNCTION public.apply_recharge(p_user uuid, p_store text, p_txn text, p_product text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare pk public.recharge_packages;p public.profiles;lvl int;existing public.purchases;begin if p_user is null or p_store not in('google_play','app_store') or nullif(trim(p_txn),'') is null or nullif(trim(p_product),'') is null then raise exception 'invalid purchase'; end if;
perform pg_advisory_xact_lock(hashtextextended(p_store||':'||p_txn,0));
select * into pk from public.recharge_packages where product_id=p_product; if not found then raise exception 'unknown product'; end if;
select * into existing from public.purchases where store=p_store and txn_id=p_txn;
if found then
 if existing.user_id<>p_user then raise exception 'purchase belongs to another account'; end if;
 if (existing.product_id is not null and existing.product_id<>p_product) or existing.usd_cents<>pk.usd_cents or existing.coins<>pk.coins then raise exception 'purchase product mismatch'; end if;
 return jsonb_build_object('status','replayed','coins',existing.coins,'product_id',p_product,'transaction_id',p_txn);
end if;
if not pk.active then raise exception 'product unavailable'; end if;
perform 1 from public.profiles where id=p_user and status='active' for update; if not found then raise exception 'account restricted'; end if;
if not exists(select 1 from public.wallets where user_id=p_user) then raise exception 'wallet missing'; end if;
insert into public.purchases(store,txn_id,user_id,usd_cents,coins,product_id) values(p_store,p_txn,p_user,pk.usd_cents,pk.coins,p_product);update public.wallets set coins=coins+pk.coins where user_id=p_user;insert into public.ledger(user_id,kind,coin_delta,ref,idempotency_key) values(p_user,'recharge',pk.coins,jsonb_build_object('store',p_store,'product',p_product,'transaction_id',p_txn),p_store||':'||p_txn);select * into p from public.profiles where id=p_user for update;if p.svip_cycle_start is not null and p.svip_cycle_start+interval'90 days'<=now() then update public.profiles set svip_cycle_start=null,svip_cycle_cents=0,svip_level=0 where id=p_user;p.svip_cycle_cents:=0;p.svip_cycle_start:=null;end if;p.svip_cycle_cents:=p.svip_cycle_cents+pk.usd_cents;if p.svip_cycle_start is null and p.svip_cycle_cents>=5000 then p.svip_cycle_start:=now();end if;select coalesce(max(level),0) into lvl from public.svip_thresholds where usd_cents<=p.svip_cycle_cents;update public.profiles set svip_cycle_cents=p.svip_cycle_cents,svip_cycle_start=p.svip_cycle_start,svip_level=case when p.svip_cycle_start is null then 0 else lvl end where id=p_user;return jsonb_build_object('status','credited','coins',pk.coins,'product_id',p_product,'transaction_id',p_txn);end $function$;

CREATE OR REPLACE FUNCTION public.claim_svip_friday()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_user uuid := auth.uid();
 v_local timestamp := pg_catalog.statement_timestamp() at time zone 'Asia/Riyadh';
 v_sunday_start timestamp;
 v_week_date date;
 v_profile public.profiles%rowtype;
 v_reward bigint;
begin
 if v_user is null then raise exception 'Sign in required'; end if;
 v_sunday_start := pg_catalog.date_trunc('week',v_local) + interval '6 days 21 hours';
 if v_local < v_sunday_start then v_sunday_start := v_sunday_start - interval '7 days'; end if;
 v_week_date:=v_sunday_start::date;
 select * into v_profile from public.profiles
 where id=v_user and status='active' for update;
 if not found then raise exception 'Account unavailable'; end if;
 if v_profile.svip_level not between 1 and 10
    or v_profile.svip_cycle_start is null
    or v_profile.svip_cycle_start + interval '90 days' <= pg_catalog.statement_timestamp()
 then raise exception 'No active SVIP'; end if;
 if v_profile.svip_last_claim = v_week_date then
    raise exception 'SVIP weekly reward already claimed';
 end if;
 -- A new/renewed cycle cannot claim an older weekly period that began
 -- before the member qualified for SVIP.
 if v_profile.svip_cycle_start >
    (v_sunday_start at time zone 'Asia/Riyadh')
 then raise exception 'SVIP weekly reward unlocks Sunday 21:00 Saudi time'; end if;
 select coins into v_reward from public.svip_friday_rewards
 where level=v_profile.svip_level;
 if v_reward is null or v_reward<=0 then raise exception 'SVIP reward catalog unavailable'; end if;
 update public.wallets set coins=coins+v_reward where user_id=v_user;
 if not found then raise exception 'SVIP wallet unavailable'; end if;
 update public.profiles set svip_last_claim=v_week_date where id=v_user;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,idempotency_key,ref)
 values(v_user,'svip_friday',v_reward,0,'svip-'||v_week_date,
 pg_catalog.jsonb_build_object('level',v_profile.svip_level,
 'weekly_sunday',v_week_date,'schedule','Sunday 21:00 Asia/Riyadh'));
end;
$function$;

CREATE OR REPLACE FUNCTION public.claim_vip_daily()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_user uuid := auth.uid();
 v_date date := (pg_catalog.statement_timestamp() at time zone 'Asia/Riyadh')::date;
 v_profile public.profiles%rowtype;
 v_reward bigint;
begin
 if v_user is null then raise exception 'Sign in required'; end if;
 select * into v_profile from public.profiles
 where id=v_user and status='active' for update;
 if not found then raise exception 'Account unavailable'; end if;
 if v_profile.vip_level not between 1 and 10
    or v_profile.vip_expires_at is null
    or v_profile.vip_expires_at<=pg_catalog.statement_timestamp()
 then raise exception 'No active VIP'; end if;
 if v_profile.vip_last_claim=v_date then raise exception 'VIP reward already claimed today'; end if;
 select coins into v_reward from public.vip_daily_rewards
 where level=v_profile.vip_level;
 if v_reward is null or v_reward<=0 then raise exception 'VIP reward catalog unavailable'; end if;
 update public.wallets set coins=coins+v_reward where user_id=v_user;
 if not found then raise exception 'VIP wallet unavailable'; end if;
 update public.profiles set vip_last_claim=v_date where id=v_user;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,idempotency_key,ref)
 values(v_user,'vip_daily',v_reward,0,'vip-'||v_date,
 pg_catalog.jsonb_build_object('level',v_profile.vip_level,'claim_day',v_date,'time_zone','Asia/Riyadh'));
end;
$function$;

CREATE OR REPLACE FUNCTION nimzo_private.pay_svip_sunday_rewards()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_now timestamptz := pg_catalog.statement_timestamp();
 v_local timestamp := v_now AT TIME ZONE 'Asia/Riyadh';
 v_this_sunday timestamp;
 v_sunday_utc timestamptz;
 v_week_date date;
 v_user record;
 v_amount bigint;
 v_ledger_id bigint;
 v_wallet_id uuid;
 v_count integer := 0;
 v_already integer := 0;
 v_failed integer := 0;
 v_total bigint := 0;
BEGIN
 -- Retry slots are 21:00, 21:15, 21:30 and 21:45 Saudi time.
 -- Anything outside this window, including an accidentally invoked manual
 -- RPC, is a NO-OP. UTC never changes its offset for Asia/Riyadh.
 IF extract(isodow FROM v_local)<>7
    OR extract(hour FROM v_local)<>21 THEN
   RETURN pg_catalog.jsonb_build_object(
     'status','outside_sunday_21_hour','credited',0);
 END IF;
 v_this_sunday := pg_catalog.date_trunc('week',v_local)
                   + interval '6 days 21 hours';
 v_sunday_utc := v_this_sunday AT TIME ZONE 'Asia/Riyadh';
 IF v_now < v_sunday_utc THEN
   RETURN pg_catalog.jsonb_build_object('status','not_due','credited',0);
 END IF;
 v_week_date := v_this_sunday::date;

 -- Prevent overlapping cron attempts and maintain one atomic accounting
 -- transaction per run. Manual claims serialize on each profiles row.
 PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('nimzo-svip-sunday:'||v_week_date::text,0)
 );
 FOR v_user IN
   SELECT p.id,p.svip_level,p.svip_last_claim
   FROM public.profiles p
   WHERE p.status='active'
     AND p.svip_level BETWEEN 1 AND 10
     AND p.svip_cycle_start IS NOT NULL
     AND p.svip_cycle_start <= v_sunday_utc
     AND p.svip_cycle_start + interval '90 days' > v_now
     AND p.svip_last_claim IS DISTINCT FROM v_week_date
   ORDER BY p.id
   FOR UPDATE OF p SKIP LOCKED
 LOOP
   BEGIN
     SELECT coins INTO v_amount
     FROM public.svip_friday_rewards
     WHERE level=v_user.svip_level;
     IF v_amount IS NULL OR v_amount<=0 THEN
       RAISE EXCEPTION 'SVIP reward catalog missing for current tier';
     END IF;
     v_ledger_id := NULL;
     INSERT INTO public.ledger
       (user_id,kind,coin_delta,diamond_delta,idempotency_key,ref)
     VALUES(
       v_user.id,'svip_friday',v_amount,0,
       'svip-'||v_week_date::text,
       pg_catalog.jsonb_build_object(
         'level',v_user.svip_level,'weekly_sunday',v_week_date,
         'schedule','Sunday 21:00 Asia/Riyadh','source','automatic')
     )
     ON CONFLICT (user_id,idempotency_key,kind) DO NOTHING
     RETURNING id INTO v_ledger_id;
     IF v_ledger_id IS NULL THEN
       -- Historical/manual row already exists; align claim flag, never
       -- create a second ledger credit.
       UPDATE public.profiles
       SET svip_last_claim=v_week_date WHERE id=v_user.id;
       v_already := v_already+1;
       CONTINUE;
     END IF;
     v_wallet_id:=NULL;
     UPDATE public.wallets SET coins=coins+v_amount
     WHERE user_id=v_user.id RETURNING user_id INTO v_wallet_id;
     IF v_wallet_id IS NULL THEN
       RAISE EXCEPTION 'SVIP member wallet not available';
     END IF;
     UPDATE public.profiles SET svip_last_claim=v_week_date
     WHERE id=v_user.id;
     v_count:=v_count+1;
     v_total:=v_total+v_amount;
   EXCEPTION WHEN OTHERS THEN
     -- Per-user subtransaction rolls back ledger, balance and claim flag
     -- together; one damaged account must not cancel all other payouts.
     v_failed:=v_failed+1;
     RAISE WARNING 'SVIP weekly payout skipped one account (SQLSTATE %)',
       SQLSTATE;
   END;
 END LOOP;

 INSERT INTO nimzo_private.svip_sunday_payout_runs
  (week_sunday,credited_count,already_paid_count,failed_count,payout_coins,status)
 VALUES(v_week_date,v_count,v_already,v_failed,v_total,
    CASE WHEN v_failed=0 THEN 'succeeded' ELSE 'partial_failure' END);
 RETURN pg_catalog.jsonb_build_object(
   'status',CASE WHEN v_failed=0 THEN 'succeeded' ELSE 'partial_failure' END,
   'week_sunday',v_week_date,'credited',v_count,
   'already_paid',v_already,'failed',v_failed,'coins',v_total);
END;
$function$;

CREATE OR REPLACE FUNCTION nimzo_private.phoenix_room_entry()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.phoenix_room_entries(room_id,user_id,display_name,created_at)
  SELECT NEW.room_id,p.id,
    COALESCE(NULLIF(p.display_name,''),NULLIF(p.username,''),'NIMZO user'),
    COALESCE(NEW.joined_at,pg_catalog.clock_timestamp())
  FROM public.profiles p
  WHERE p.id=NEW.user_id AND p.status='active'
    AND (
      (p.vip_level BETWEEN 1 AND 10
       AND p.vip_expires_at>pg_catalog.clock_timestamp())
      OR
      (p.svip_level BETWEEN 1 AND 10 AND p.svip_cycle_start IS NOT NULL
       AND p.svip_cycle_start+interval '90 days'>pg_catalog.clock_timestamp())
    );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.phoenix_membership(p_user uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 SELECT pg_catalog.jsonb_build_object(
    'vip_level',CASE WHEN p.status='active'
      AND p.vip_expires_at>pg_catalog.now()
      THEN COALESCE(p.vip_level,0) ELSE 0 END,
    'vip_expires_at',p.vip_expires_at,
    'svip_level',CASE WHEN p.status='active' AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days'>pg_catalog.now()
      THEN COALESCE(p.svip_level,0) ELSE 0 END,
    'svip_expires_at',p.svip_cycle_start+interval '90 days',
    'server_now',pg_catalog.now())
 FROM public.profiles p
 WHERE p.id=p_user AND auth.uid() IS NOT NULL;
$function$;

CREATE OR REPLACE FUNCTION public.purchase_normal_vip(p_tier integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_coins bigint;
  v_days integer;
  v_existing jsonb;
  v_level integer;
  v_expiry timestamptz;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF p_tier NOT BETWEEN 1 AND 10 THEN RAISE EXCEPTION 'Invalid VIP tier'; END IF;
  IF p_key IS NULL OR length(trim(p_key))<8 OR length(p_key)>128 THEN
    RAISE EXCEPTION 'Invalid purchase idempotency key';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('normal_vip:' || v_user::text || ':' || p_key, 0)
  );
  SELECT ref INTO v_existing
  FROM public.ledger
  WHERE user_id=v_user AND kind='vip_purchase'
  AND idempotency_key='vip:' || p_key;
  IF FOUND THEN
    IF (v_existing->>'tier')::integer IS DISTINCT FROM p_tier THEN
      RAISE EXCEPTION 'Purchase idempotency payload mismatch';
    END IF;
    RETURN pg_catalog.jsonb_build_object(
      'status','replayed','tier',p_tier,'expires_at',v_existing->>'expires_at'
    );
  END IF;

  SELECT coin_price,duration_days INTO v_coins,v_days
  FROM public.normal_vip_catalog WHERE tier=p_tier;
  IF v_coins IS NULL THEN RAISE EXCEPTION 'VIP tier not available'; END IF;

  SELECT vip_level,vip_expires_at INTO v_level,v_expiry
  FROM public.profiles
  WHERE id=v_user AND status='active' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account unavailable'; END IF;

  UPDATE public.wallets SET coins=coins-v_coins
  WHERE user_id=v_user AND coins>=v_coins;
  IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient coins'; END IF;

  -- Same-tier renewals extend; upgrades start a fresh paid cycle.
  v_expiry := CASE
    WHEN v_level=p_tier AND v_expiry>pg_catalog.now()
      THEN v_expiry
    ELSE pg_catalog.now()
  END + pg_catalog.make_interval(days=>v_days);

  UPDATE public.profiles
  SET vip_level=p_tier,vip_expires_at=v_expiry
  WHERE id=v_user;

  INSERT INTO public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  VALUES(
    v_user,'vip_purchase',-v_coins,0,
    pg_catalog.jsonb_build_object(
      'tier',p_tier,'price',v_coins,'expires_at',v_expiry,
      'source','nimzo_verified_normal_vip'
    ),
    'vip:' || p_key
  );

  RETURN pg_catalog.jsonb_build_object(
    'status','ok','tier',p_tier,'cost',v_coins,'expires_at',v_expiry
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.vip_status()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  WITH clock AS (
    SELECT pg_catalog.statement_timestamp() AS now_utc,
      pg_catalog.statement_timestamp() AT TIME ZONE 'Asia/Riyadh' AS local_time
  ), periods AS (
    SELECT now_utc,local_time, local_time::date AS local_day,
      pg_catalog.date_trunc('week',local_time)
        + interval '6 days 21 hours' AS this_sunday_start
    FROM clock
  ), period AS (
    SELECT now_utc,local_time,local_day,this_sunday_start,
      CASE WHEN local_time < this_sunday_start
        THEN this_sunday_start-interval '7 days'
        ELSE this_sunday_start
      END AS active_week_start,
      CASE WHEN local_time < this_sunday_start
        THEN this_sunday_start ELSE this_sunday_start+interval '7 days'
      END AT TIME ZONE 'Asia/Riyadh' AS next_auto_at
    FROM periods
  )
  SELECT pg_catalog.jsonb_build_object(
    'retired',false,
    'purchases_enabled',true,
    'claims_enabled',true,
    'vip_daily_reward_coins',(SELECT coins FROM public.vip_daily_rewards WHERE level=p.vip_level),
    'svip_weekly_reward_coins',(SELECT coins FROM public.svip_friday_rewards WHERE level=p.svip_level),
    'server_now',c.now_utc,
    'svip_expires_at',p.svip_cycle_start+interval '90 days',
    'vip_level', CASE WHEN p.vip_expires_at > c.now_utc
      AND p.status='active' THEN p.vip_level ELSE 0 END,
    'vip_expires_at',p.vip_expires_at,
    'vip_daily_claimed_today', p.vip_last_claim=c.local_day,
    'svip_level',CASE WHEN p.status='active'
      AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days' > c.now_utc
      THEN p.svip_level ELSE 0 END,
    'svip_cycle_active', p.status='active'
      AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days' > c.now_utc,
    'svip_cycle_cents',CASE WHEN p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start+interval '90 days' <= c.now_utc
      THEN 0 ELSE p.svip_cycle_cents END,
    'svip_weekly_claimed', p.svip_last_claim=c.active_week_start::date,
    'svip_current_week', c.active_week_start::date,
    'svip_auto_enabled',true,
    'svip_next_payout_at',c.next_auto_at,
    'svip_weekly_claimable', p.status='active'
      AND p.svip_level BETWEEN 1 AND 10
      AND p.svip_cycle_start IS NOT NULL
      AND p.svip_cycle_start <=
        (c.active_week_start AT TIME ZONE 'Asia/Riyadh')
      AND p.svip_cycle_start+interval '90 days'>c.now_utc
      AND p.svip_last_claim IS DISTINCT FROM c.active_week_start::date
      AND c.local_time >= c.active_week_start+interval '1 hour',
    'reward_timezone','Asia/Riyadh'
  )
  FROM public.profiles p CROSS JOIN period c
  WHERE p.id=auth.uid()
$function$;

-- No private function or privileged recharge endpoint is publicly executable.
REVOKE ALL ON FUNCTION public.purchase_normal_vip(integer,text),
 public.claim_vip_daily(),public.claim_svip_friday(),public.vip_status(),
 public.phoenix_membership(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_normal_vip(integer,text),
 public.claim_vip_daily(),public.claim_svip_friday(),public.vip_status(),
 public.phoenix_membership(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.apply_recharge(uuid,text,text,text),
 public.activate_vip(uuid,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.apply_recharge(uuid,text,text,text) TO service_role;
REVOKE ALL ON FUNCTION nimzo_private.pay_svip_sunday_rewards(),
 nimzo_private.phoenix_room_entry() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION nimzo_private.pay_svip_sunday_rewards() TO postgres;
ALTER TABLE public.normal_vip_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.svip_thresholds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vip_daily_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.svip_friday_rewards ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.normal_vip_catalog,public.svip_thresholds,
 public.vip_daily_rewards,public.svip_friday_rewards FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.normal_vip_catalog,public.svip_thresholds,
 public.vip_daily_rewards,public.svip_friday_rewards TO authenticated;
DROP TRIGGER IF EXISTS phoenix_room_entry ON public.room_members;
CREATE TRIGGER phoenix_room_entry AFTER INSERT ON public.room_members
 FOR EACH ROW EXECUTE FUNCTION nimzo_private.phoenix_room_entry();
SELECT cron.schedule('nimzo_svip_sunday_21_riyadh','0,15,30,45 18 * * 0',
 'SELECT nimzo_private.pay_svip_sunday_rewards();');
DO $enable$
DECLARE j bigint;
BEGIN
 FOR j IN SELECT jobid FROM cron.job WHERE jobname='nimzo_svip_sunday_21_riyadh' LOOP
   PERFORM cron.alter_job(j,active:=true);
 END LOOP;
END;
$enable$;
NOTIFY pgrst,'reload schema';
COMMIT;

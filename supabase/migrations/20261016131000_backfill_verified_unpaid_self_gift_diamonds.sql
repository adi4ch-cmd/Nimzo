-- Backfill only historically settled self-gift diamonds that were never
-- credited. Never change spent coins, prior exchanges or existing earned
-- diamonds. Idempotent via unique (user_id,idempotency_key,kind).
WITH earned AS (
  SELECT receiver_id AS user_id,
         SUM((total_coins * 45) / 100)::bigint AS expected_diamonds,
         COUNT(*)::bigint AS self_gifts
  FROM public.gift_events
  WHERE sender_id = receiver_id
  GROUP BY receiver_id
),
previously_paid AS (
  SELECT user_id,
         SUM(GREATEST(diamond_delta, 0))::bigint AS diamonds_paid
  FROM public.ledger
  WHERE kind IN ('gift_received','profile_gift_received','moment_gift_received',
                 'self_gift_45pct_adjustment')
  GROUP BY user_id
),
shortfalls AS (
  SELECT e.user_id, e.self_gifts, e.expected_diamonds,
         COALESCE(p.diamonds_paid,0) AS previously_paid,
         GREATEST(0,e.expected_diamonds-COALESCE(p.diamonds_paid,0))::bigint AS owed
  FROM earned e LEFT JOIN previously_paid p USING (user_id)
),
credits AS (
  INSERT INTO public.ledger
    (user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  SELECT s.user_id,
         'self_gift_45pct_adjustment',
         0,
         s.owed,
         jsonb_build_object(
           'policy','45pct_self_gift',
           'event_count',s.self_gifts,
           'expected',s.expected_diamonds,
           'previously_paid',s.previously_paid,
           'source','settled_gift_events',
           'coins_adjusted',false),
         'selfgift45percent:20261016:verified'
  FROM shortfalls s
  WHERE s.owed > 0
  ON CONFLICT (user_id,idempotency_key,kind) DO NOTHING
  RETURNING user_id,diamond_delta
)
UPDATE public.wallets w
SET diamonds=w.diamonds+c.diamond_delta
FROM credits c WHERE w.user_id=c.user_id;
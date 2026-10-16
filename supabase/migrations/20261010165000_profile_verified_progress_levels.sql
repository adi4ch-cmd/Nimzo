-- Server-derived, non-editable progress tiers. No identities/wallets removed.
-- Level n starts at (n-1)^2 * unit. This is a display-only level scale,
-- not a permission to spend coins or receive VIP/gifts.
BEGIN;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS wealth_level integer GENERATED ALWAYS AS (
    LEAST(120, 1 + FLOOR(SQRT(GREATEST(COALESCE(wealth_coins,0),0)::numeric / 10000))::integer)
  ) STORED,
  ADD COLUMN IF NOT EXISTS charm_level integer GENERATED ALWAYS AS (
    LEAST(120, 1 + FLOOR(SQRT(GREATEST(COALESCE(charm_diamonds,0),0)::numeric / 100))::integer)
  ) STORED,
  ADD COLUMN IF NOT EXISTS active_level integer GENERATED ALWAYS AS (
    LEAST(120, 1 + FLOOR(SQRT(GREATEST(COALESCE(active_points,0),0)::numeric / 20))::integer)
  ) STORED;
REVOKE UPDATE (wealth_level, charm_level, active_level)
 ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
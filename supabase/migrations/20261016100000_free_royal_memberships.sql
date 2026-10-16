-- NIMZO royalty-free cosmetic identity system: separate from retired paid VIP.
-- Never restore legacy profiles.vip_level/svip_level or their disabled RPCs.
-- No purchases, rewards, wallet mutations, expiration or admin privileges.
BEGIN;

CREATE TABLE IF NOT EXISTS public.free_memberships (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  vip_tier integer CHECK (vip_tier BETWEEN 1 AND 8),
  svip_tier integer CHECK (svip_tier BETWEEN 1 AND 9),
  display_kind text CHECK (display_kind IN ('vip','svip')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT free_membership_display_is_activated CHECK (
    display_kind IS NULL
    OR (display_kind = 'vip' AND vip_tier IS NOT NULL)
    OR (display_kind = 'svip' AND svip_tier IS NOT NULL)
  )
);

ALTER TABLE public.free_memberships ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.free_memberships FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.free_memberships TO authenticated;
-- Any signed-in person may see the publicly displayed cosmetics.
DROP POLICY IF EXISTS "Free royal identities are readable" ON public.free_memberships;
CREATE POLICY "Free royal identities are readable"
  ON public.free_memberships FOR SELECT TO authenticated USING (true);
-- Intentionally no INSERT/UPDATE/DELETE policy: only the narrow RPC mutates.

CREATE OR REPLACE FUNCTION public.activate_free_membership(
  p_kind text, p_tier integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_status text;
  v_record public.free_memberships;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Sign in required' USING ERRCODE = '28000';
  END IF;
  IF p_kind NOT IN ('vip', 'svip')
      OR p_tier IS NULL
      OR (p_kind = 'vip' AND p_tier NOT BETWEEN 1 AND 8)
      OR (p_kind = 'svip' AND p_tier NOT BETWEEN 1 AND 9) THEN
    RAISE EXCEPTION 'Invalid free membership theme' USING ERRCODE = '22023';
  END IF;
  SELECT status INTO v_status FROM public.profiles
    WHERE id = v_user FOR UPDATE;
  IF v_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'Account not active' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.free_memberships AS fm (
    user_id, vip_tier, svip_tier, display_kind, updated_at
  ) VALUES (
    v_user,
    CASE WHEN p_kind = 'vip' THEN p_tier END,
    CASE WHEN p_kind = 'svip' THEN p_tier END,
    p_kind, now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    vip_tier = CASE WHEN p_kind = 'vip' THEN EXCLUDED.vip_tier ELSE fm.vip_tier END,
    svip_tier = CASE WHEN p_kind = 'svip' THEN EXCLUDED.svip_tier ELSE fm.svip_tier END,
    display_kind = p_kind,
    updated_at = now()
  RETURNING * INTO v_record;

  RETURN pg_catalog.jsonb_build_object(
    'vip_tier', v_record.vip_tier,
    'svip_tier', v_record.svip_tier,
    'display_kind', v_record.display_kind,
    'price_coins', 0,
    'expires_at', NULL
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.activate_free_membership(text,integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_free_membership(text,integer)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;

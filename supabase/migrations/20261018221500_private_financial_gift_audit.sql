-- Retire client-side financial and gift history access while retaining the
-- authoritative audit trail. No wallet, diamond, transaction or profile rows
-- are deleted. Car sending continues through SECURITY DEFINER RPCs.
revoke select on table public.ledger from public, anon, authenticated;
revoke select on table public.gift_events from public, anon, authenticated;

-- Real-time Sports Car rendering still reads verified gift_animation_events,
-- not ledger or gift_events. Do not revoke this read grant.

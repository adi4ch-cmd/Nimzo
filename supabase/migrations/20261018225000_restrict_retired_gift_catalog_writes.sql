-- Retirement hardening: old APKs must not mutate the catalog or destroy
-- reconciliable financial records. Sports Car remains readable and purchaseable
-- through the separately audited SECURITY DEFINER gift RPC.
-- Do not drop, truncate or rewrite ledgers, payments or wallet balances.
revoke insert, update, delete, truncate on table public.gifts
  from public, anon, authenticated;
revoke truncate on table public.gift_events, public.gift_animation_events,
  public.ledger from public, anon, authenticated;

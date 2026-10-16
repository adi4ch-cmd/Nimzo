-- Nimzo locked 2026-10-07 SVIP tier catalogs.
-- Review and test in staging before applying to production.
-- This migration updates only catalog rows; never touches accounts, wallets,
-- transactions, existing memberships or accumulated recharge.
-- IMPORTANT: The old reward table is named svip_friday_rewards.
-- Renaming it or changing the payout scheduler is a separate task; a catalog
-- correction alone DOES NOT implement Sunday 21:00 Asia/Riyadh automation.

insert into public.svip_thresholds (level, usd_cents) values
  (1, 5000),
  (2, 20000),
  (3, 50000),
  (4, 100000),
  (5, 300000),
  (6, 1000000),
  (7, 3000000),
  (8, 7500000),
  (9, 20000000),
  (10, 50000000)
on conflict (level) do update
set usd_cents = excluded.usd_cents;

insert into public.svip_friday_rewards (level, coins) values
  (1, 2000000),
  (2, 5000000),
  (3, 10000000),
  (4, 20000000),
  (5, 40000000),
  (6, 80000000),
  (7, 150000000),
  (8, 250000000),
  (9, 450000000),
  (10, 800000000)
on conflict (level) do update
set coins = excluded.coins;

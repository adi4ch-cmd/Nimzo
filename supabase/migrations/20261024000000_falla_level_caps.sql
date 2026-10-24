-- Extend existing verified progress system to match the complete set of
-- Falla level badge numbers: Wealth/Charm 0–270; Active 0–140.
-- IMPORTANT: APK did not contain a verified Falla XP progression table.
-- This migration PRESERVES NIMZO's existing XP-to-level formula unchanged,
-- extending its cap only; it must not be presented as exact Falla XP parity.
-- Original counters, coins, gifts, ledgers and histories are not reset.
begin;
alter table public.profiles
  alter column wealth_level set expression as
    (least(270, 1 + floor(sqrt(greatest(coalesce(wealth_coins,0),0)::numeric / 10000))::integer)),
  alter column charm_level set expression as
    (least(270, 1 + floor(sqrt(greatest(coalesce(charm_diamonds,0),0)::numeric / 100))::integer)),
  alter column active_level set expression as
    (least(140, 1 + floor(sqrt(greatest(coalesce(active_points,0),0)::numeric / 20))::integer));
revoke update (wealth_level,charm_level,active_level)
  on public.profiles from public, anon, authenticated;
notify pgrst, 'reload schema';
commit;

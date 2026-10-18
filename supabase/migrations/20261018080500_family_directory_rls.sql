-- Live Family directory; aggregated by PostgreSQL, not by downloading all members.
-- SECURITY INVOKER keeps underlying RLS enforced for the current user.
create or replace view public.nimzo_family_directory
with (security_invoker = true)
as
select
  f.id,
  f.owner_id,
  f.name,
  f.description,
  f.created_at,
  coalesce(p.display_name, p.username, 'NIMZO Member')::text as owner_name,
  p.avatar_path as owner_avatar_path,
  (select count(*)::integer from public.nimzo_family_members m
   where m.family_id = f.id) as member_count,
  exists(select 1 from public.nimzo_family_members m
   where m.family_id = f.id and m.user_id = (select auth.uid())) as is_member
from public.nimzo_families f
left join public.profiles p on p.id = f.owner_id;
revoke all on public.nimzo_family_directory from public, anon;
grant select on public.nimzo_family_directory to authenticated;

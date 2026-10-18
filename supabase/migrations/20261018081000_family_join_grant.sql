-- Allow the existing self-join RLS policy to be reached.
-- family_join WITH CHECK restricts user_id to auth.uid(), disallows owner,
-- and requires the destination family to exist. No broad write permissions.
grant insert on public.nimzo_family_members to authenticated;

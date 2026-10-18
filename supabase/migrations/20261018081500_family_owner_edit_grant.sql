-- Enable owner-only name/description edits under the existing
-- family_edit RLS policy. Column grant explicitly excludes owner_id.
grant update (name, description) on public.nimzo_families to authenticated;

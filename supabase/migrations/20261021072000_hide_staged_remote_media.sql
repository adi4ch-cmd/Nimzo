-- Approved media for staged/inactive items is NOT publicly exposed.
-- This changes no files, coin balances, inventory or membership state.
begin;
drop policy if exists nimzo_media_read on public.nimzo_cosmetic_media;
create policy nimzo_media_read on public.nimzo_cosmetic_media
for select to authenticated using (
  approved and exists (
    select 1 from public.nimzo_cosmetic_catalog c
    where c.id = item_id and c.active
  )
);
drop policy if exists gift_animation_media_approved_read on public.gift_animation_media;
create policy gift_animation_media_approved_read on public.gift_animation_media
for select to authenticated using (
  approved and exists (
    select 1 from public.gifts g
    where g.id = gift_id and g.active
  )
);
commit;
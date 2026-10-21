-- Protect newly published animated paid room gifts from charging when
-- their required approved animation record is absent. Existing gifts stay
-- on their previous behavior (requires_approved_media defaults false).
begin;
alter table public.gifts
  add column if not exists requires_approved_media boolean not null default false;

create or replace function nimzo_internal.require_gift_media_on_activation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.active and new.requires_approved_media and not exists (
    select 1 from public.gift_animation_media m
    where m.gift_id = new.id and m.approved
  ) then
    raise exception 'Cannot activate gift without approved playback media'
      using errcode='22023';
  end if;
  return new;
end;
$$;

create or replace function nimzo_internal.reject_unplayable_settled_gift()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists (
    select 1 from public.gifts g
    where g.id = new.gift_id and g.requires_approved_media
  ) and not exists (
    select 1 from public.gift_animation_media m
    where m.gift_id = new.gift_id and m.approved
  ) then
    raise exception 'Gift animation unavailable; no coins charged'
      using errcode='22023';
  end if;
  return new;
end;
$$;

revoke all on function nimzo_internal.require_gift_media_on_activation() from public, anon, authenticated;
revoke all on function nimzo_internal.reject_unplayable_settled_gift() from public, anon, authenticated;

drop trigger if exists nimzo_validate_new_gift_media on public.gifts;
create trigger nimzo_validate_new_gift_media before insert or update
on public.gifts for each row
execute function nimzo_internal.require_gift_media_on_activation();

drop trigger if exists nimzo_guard_paid_room_gift_media on public.gift_events;
create trigger nimzo_guard_paid_room_gift_media before insert
on public.gift_events for each row
execute function nimzo_internal.reject_unplayable_settled_gift();
commit;
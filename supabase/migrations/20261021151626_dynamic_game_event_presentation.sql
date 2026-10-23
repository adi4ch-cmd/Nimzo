-- Additive verified campaign art. Existing campaigns and their dates untouched.
begin;
alter table public.banners
 add column if not exists image_sha256 text,
 add column if not exists image_byte_size bigint,
 add column if not exists image_mime_type text,
 add column if not exists image_rights_reference text,
 add column if not exists image_verified_at timestamptz,
 add column if not exists image_device_verified_at timestamptz;
create function nimzo_internal.validate_banner_publication()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_has boolean; v_changed boolean;
begin
 v_has := new.image_sha256 is not null or new.image_byte_size is not null
   or new.image_mime_type is not null or new.image_rights_reference is not null
   or new.image_verified_at is not null or new.image_device_verified_at is not null;
 v_changed := tg_op='INSERT';
 if tg_op='UPDATE' then
  v_changed:=new.image_path is distinct from old.image_path
    or (new.active and not old.active);
 end if;
 if v_has or (new.active and v_changed) then
  if new.image_byte_size>4194304 or not nimzo_internal.valid_media_publication(
    new.image_path,new.image_sha256,new.image_byte_size,new.image_mime_type,'image',
    new.image_rights_reference,new.image_verified_at,new.image_device_verified_at) then
   raise exception 'Campaign image needs verified immutable bytes and rights/device evidence'
     using errcode='22023';
  end if;
 end if;
 return new;
end $$;
revoke all on function nimzo_internal.validate_banner_publication() from public,anon,authenticated;
create trigger nimzo_banner_validate before insert or update on public.banners
 for each row execute function nimzo_internal.validate_banner_publication();
-- Existing owner-only settings writes/RLS also cover games.presentation.
-- No executable engine, room powers, payout rules or game activation is added.
commit;

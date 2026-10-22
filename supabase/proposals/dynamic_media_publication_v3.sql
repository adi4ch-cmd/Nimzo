-- REVIEW/STAGING PROPOSAL ONLY. Not applied to live; no financial rows changed.
-- Prerequisites: dynamic_* revisions/media and guard_new_paid_gift_media.
-- Existing approved media remains readable. The next approval requires verified
-- publication metadata. Paid Store settlement fails closed immediately until its
-- publication is verified; stage/test before applying. Client must separately
-- fetch/validate these exact bytes BEFORE requesting any charge.
begin;

alter table public.gift_animation_media
  add column if not exists sha256 text,
  add column if not exists byte_size bigint,
  add column if not exists mime_type text,
  add column if not exists rights_reference text,
  add column if not exists verified_at timestamptz,
  add column if not exists device_verified_at timestamptz;
alter table public.nimzo_cosmetic_media
  add column if not exists sha256 text,
  add column if not exists byte_size bigint,
  add column if not exists mime_type text,
  add column if not exists rights_reference text,
  add column if not exists verified_at timestamptz,
  add column if not exists device_verified_at timestamptz;

-- Optional image-specific integrity; primary video hashes cannot authenticate
-- a separate thumbnail. Null means legacy/unverified, never reuse video hash.
alter table public.gifts
  add column if not exists thumbnail_sha256 text,
  add column if not exists thumbnail_byte_size bigint,
  add column if not exists thumbnail_mime_type text;
alter table public.nimzo_cosmetic_media
  add column if not exists thumbnail_sha256 text,
  add column if not exists thumbnail_byte_size bigint,
  add column if not exists thumbnail_mime_type text;
alter table public.gifts add constraint nimzo_gift_thumbnail_publication_check check (
  (thumbnail_sha256 is null and thumbnail_byte_size is null and thumbnail_mime_type is null)
  or (thumbnail_sha256 is not null and thumbnail_byte_size is not null and thumbnail_mime_type is not null
    and thumbnail_sha256 ~ '^[a-f0-9]{64}$' and thumbnail_byte_size between 1 and 4194304
    and thumbnail_mime_type in ('image/png','image/jpeg','image/webp'))
);
alter table public.nimzo_cosmetic_media add constraint nimzo_store_thumbnail_publication_check check (
  (thumbnail_sha256 is null and thumbnail_byte_size is null and thumbnail_mime_type is null)
  or (thumbnail_sha256 is not null and thumbnail_byte_size is not null and thumbnail_mime_type is not null
    and thumbnail_sha256 ~ '^[a-f0-9]{64}$' and thumbnail_byte_size between 1 and 4194304
    and thumbnail_mime_type in ('image/png','image/jpeg','image/webp'))
);

-- SQL cannot decode a remote object or establish rights. Only a trusted owner
-- verification process may populate these fields after actual device playback.
create or replace function nimzo_internal.valid_media_publication(
  p_url text, p_hash text, p_bytes bigint, p_mime text, p_kind text,
  p_rights text, p_verified timestamptz, p_device timestamptz
) returns boolean language sql immutable set search_path='' as $$
 select coalesce(
   p_url ~ '^https://[^/@[:space:]:?#]+(/[^[:space:]?#]*)?$'
   and length(p_url) <= 2048
   and p_hash ~ '^[a-f0-9]{64}$'
   -- Hash in path makes object identity explicit; a query token is not identity.
   and position(p_hash in p_url) > 0
   and p_bytes between 1 and 33554432
   and ((p_kind='image' and p_mime in ('image/png','image/jpeg','image/webp'))
     or (p_kind in ('mp4','vap') and p_mime='video/mp4')
     or (p_kind='svga' and p_mime='application/x-svga'))
   and length(btrim(p_rights)) between 1 and 500
   and p_verified is not null and p_device is not null, false)
$$;
revoke all on function nimzo_internal.valid_media_publication(text,text,bigint,text,text,text,timestamptz,timestamptz)
 from public,anon,authenticated;

create or replace function nimzo_internal.validate_media_publication()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_url text;
begin
  if tg_table_name='gift_animation_media' then v_url:=new.video_url;
  else v_url:=new.asset_url; end if;
  if new.approved and not nimzo_internal.valid_media_publication(
    v_url,new.sha256,new.byte_size,new.mime_type,new.media_kind,
    new.rights_reference,new.verified_at,new.device_verified_at
  ) then
    raise exception 'Media publication needs verified immutable bytes and device/rights evidence'
      using errcode='22023';
  end if;
  return new;
end;
$$;
revoke all on function nimzo_internal.validate_media_publication() from public,anon,authenticated;
create trigger nimzo_validate_publication before insert or update
on public.gift_animation_media for each row execute function nimzo_internal.validate_media_publication();
create trigger nimzo_validate_publication before insert or update
on public.nimzo_cosmetic_media for each row execute function nimzo_internal.validate_media_publication();

-- Apply strict publication to new paid gifts without changing any existing gift.
-- A publisher cannot bypass the gate by omitting the old opt-in boolean.
create or replace function nimzo_internal.require_new_gift_publication()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.coin_price > 0 then new.requires_approved_media:=true; end if;
  return new;
end;
$$;
revoke all on function nimzo_internal.require_new_gift_publication() from public,anon,authenticated;
create trigger nimzo_00_require_new_publication before insert on public.gifts
for each row execute function nimzo_internal.require_new_gift_publication();

-- Lock the publication and catalog rows while checking. Concurrent deactivation
-- or object replacement must serialize with settlement, not race past the guard.
create or replace function nimzo_internal.reject_unplayable_settled_gift()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_requires boolean; v_active boolean; v_media public.gift_animation_media%rowtype;
begin
  select g.requires_approved_media,g.active into v_requires,v_active
    from public.gifts g where g.id=new.gift_id for share;
  if v_requires then
    select * into v_media from public.gift_animation_media m
      where m.gift_id=new.gift_id and m.approved for share;
    if v_active is not true or not found or not nimzo_internal.valid_media_publication(
      v_media.video_url,v_media.sha256,v_media.byte_size,v_media.mime_type,
      v_media.media_kind,v_media.rights_reference,v_media.verified_at,v_media.device_verified_at
    ) then
      raise exception 'Gift publication unavailable; no coins charged' using errcode='22023';
    end if;
  end if;
  return new;
end;
$$;

-- BEFORE ledger insertion is inside the existing atomic RPC: any exception
-- rolls back earlier wallet/ownership changes too. Old ledger rows untouched.
create or replace function nimzo_internal.guard_store_publication_charge()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_media public.nimzo_cosmetic_media%rowtype;
begin
  if new.kind='store_purchase' then
    select m.* into v_media from public.nimzo_cosmetic_media m
      join public.nimzo_cosmetic_catalog c on c.id=m.item_id
      where m.item_id=new.ref->>'item_id' and m.approved and c.active
        and c.coin_price=-(new.coin_delta)
      for share of m,c;
    if not found or not nimzo_internal.valid_media_publication(
      v_media.asset_url,v_media.sha256,v_media.byte_size,v_media.mime_type,
      v_media.media_kind,v_media.rights_reference,v_media.verified_at,v_media.device_verified_at
    ) then
      raise exception 'Store publication unavailable; no coins charged' using errcode='22023';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function nimzo_internal.guard_store_publication_charge() from public,anon,authenticated;
create trigger nimzo_validate_store_publication_charge before insert on public.ledger
for each row execute function nimzo_internal.guard_store_publication_charge();
commit;

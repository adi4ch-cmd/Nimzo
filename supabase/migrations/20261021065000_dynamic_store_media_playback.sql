-- Expand approved Store media from thumbnail-only to functional visuals.
-- Wallet/purchases, retired memberships, ownership and existing media untouched.
begin;
alter table public.nimzo_cosmetic_media
  add column if not exists asset_url text,
  add column if not exists media_kind text not null default 'image';
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.nimzo_cosmetic_media'::regclass
      and conname='nimzo_cosmetic_asset_https_check'
  ) then
    alter table public.nimzo_cosmetic_media add constraint nimzo_cosmetic_asset_https_check
      check (asset_url is null or (asset_url ~ '^https://[^[:space:]]+$' and length(asset_url)<=2048));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.nimzo_cosmetic_media'::regclass
      and conname='nimzo_cosmetic_media_kind_check'
  ) then
    alter table public.nimzo_cosmetic_media add constraint nimzo_cosmetic_media_kind_check
      check (media_kind in ('image','svga','vap'));
  end if;
end;
$$;
commit;
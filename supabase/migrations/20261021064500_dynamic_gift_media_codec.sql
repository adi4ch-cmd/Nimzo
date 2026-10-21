-- Separate, additive media codec metadata. Paid gift settlement unchanged.
begin;
alter table public.gift_animation_media
  add column if not exists media_kind text not null default 'mp4';
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.gift_animation_media'::regclass
      and conname='nimzo_gift_media_kind_check'
  ) then
    alter table public.gift_animation_media
      add constraint nimzo_gift_media_kind_check
      check (media_kind in ('mp4','vap','svga'));
  end if;
end;
$$;
commit;
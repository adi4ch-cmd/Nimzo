-- Additive, non-financial Dynamic Content foundation.
-- Existing gifts, Store ownership, user accounts, rooms, wallets and old VIP cleanup are untouched.
begin;

create table if not exists public.nimzo_content_revisions (
  channel text primary key check (channel in ('gifts','store','banners','games','settings')),
  revision bigint not null default 1 check (revision >= 1),
  updated_at timestamptz not null default now()
);

create table if not exists public.nimzo_remote_settings (
  key text primary key check (key ~ '^[a-z][a-z0-9_.-]{2,79}$'),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object' and pg_column_size(payload) <= 16384),
  active boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.nimzo_cosmetic_media (
  item_id text primary key references public.nimzo_cosmetic_catalog(id) on delete restrict,
  thumbnail_url text not null check (thumbnail_url ~ '^https://[^[:space:]]+$' and length(thumbnail_url) <= 2048),
  approved boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.nimzo_content_revisions enable row level security;
alter table public.nimzo_remote_settings enable row level security;
alter table public.nimzo_cosmetic_media enable row level security;

revoke all on public.nimzo_content_revisions from public, anon, authenticated;
revoke all on public.nimzo_remote_settings from public, anon, authenticated;
revoke all on public.nimzo_cosmetic_media from public, anon, authenticated;
grant select on public.nimzo_content_revisions to authenticated;
grant select on public.nimzo_remote_settings to authenticated;
grant select on public.nimzo_cosmetic_media to authenticated;

create policy nimzo_revision_read on public.nimzo_content_revisions
for select to authenticated using (true);
create policy nimzo_remote_settings_read on public.nimzo_remote_settings
for select to authenticated using (active);
create policy nimzo_media_read on public.nimzo_cosmetic_media
for select to authenticated using (approved);

insert into public.nimzo_content_revisions(channel)
values ('gifts'),('store'),('banners'),('games'),('settings')
on conflict (channel) do nothing;

create schema if not exists nimzo_internal;
revoke all on schema nimzo_internal from public, anon, authenticated;

create or replace function nimzo_internal.bump_content_revision()
returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  insert into public.nimzo_content_revisions(channel, revision, updated_at)
  values (tg_argv[0], 1, now())
  on conflict (channel) do update
  set revision = public.nimzo_content_revisions.revision + 1,
      updated_at = now();
  return null;
end;
$$;
revoke all on function nimzo_internal.bump_content_revision() from public, anon, authenticated;

create trigger nimzo_revision_gifts after insert or update or delete
on public.gifts for each statement execute function nimzo_internal.bump_content_revision('gifts');
create trigger nimzo_revision_gift_media after insert or update or delete
on public.gift_animation_media for each statement execute function nimzo_internal.bump_content_revision('gifts');
create trigger nimzo_revision_store after insert or update or delete
on public.nimzo_cosmetic_catalog for each statement execute function nimzo_internal.bump_content_revision('store');
create trigger nimzo_revision_store_media after insert or update or delete
on public.nimzo_cosmetic_media for each statement execute function nimzo_internal.bump_content_revision('store');
create trigger nimzo_revision_banners after insert or update or delete
on public.banners for each statement execute function nimzo_internal.bump_content_revision('banners');
create trigger nimzo_revision_games after insert or update or delete
on public.game_catalog for each statement execute function nimzo_internal.bump_content_revision('games');
create trigger nimzo_revision_settings after insert or update or delete
on public.nimzo_remote_settings for each statement execute function nimzo_internal.bump_content_revision('settings');

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname='supabase_realtime'
         and schemaname='public' and tablename='nimzo_content_revisions'
     ) then
    alter publication supabase_realtime add table public.nimzo_content_revisions;
  end if;
end;
$$;
commit;

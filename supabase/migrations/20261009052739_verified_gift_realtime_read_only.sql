-- Existing client subscriptions require publication membership. Keep all
-- country/room SELECT policies; settlements alone produce animation events.
alter table public.gift_animation_events enable row level security;
alter table public.gift_animation_media enable row level security;
revoke all on public.gift_animation_events, public.gift_animation_media from public, anon, authenticated;
grant select on public.gift_animation_events, public.gift_animation_media to authenticated;

do $$
begin
  if not exists(select 1 from pg_publication where pubname='supabase_realtime') then
    raise exception 'Supabase Realtime publication is unavailable';
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
      and schemaname='public' and tablename='gift_animation_events') then
    alter publication supabase_realtime add table public.gift_animation_events;
  end if;
end $$;

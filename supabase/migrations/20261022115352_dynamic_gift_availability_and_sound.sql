-- Additive publication options. Existing availability, prices and media remain unchanged.
begin;
alter table public.gifts
 add column if not exists available_from timestamptz,
 add column if not exists available_until timestamptz,
 add column if not exists priority integer not null default 0,
 add column if not exists min_vip_tier integer not null default 0;
alter table public.gifts add constraint nimzo_gift_availability_window
 check(available_from is null or available_until is null or available_until>available_from);
alter table public.gifts add constraint nimzo_gift_min_vip check(min_vip_tier between 0 and 10);
alter table public.gift_animation_media
 add column if not exists sound_enabled boolean not null default false,
 add column if not exists duration_ms integer check(duration_ms between 1 and 120000),
 add column if not exists aspect_ratio numeric check(aspect_ratio>0 and aspect_ratio<=10),
 add column if not exists transparent boolean,
 add column if not exists source_record text check(length(source_record)<=2048);
create function nimzo_internal.guard_gift_availability()
returns trigger language plpgsql security definer set search_path='' as $$
declare g public.gifts%rowtype; v_level integer;
begin
 select * into g from public.gifts where id=new.gift_id for share;
 if not found or not g.active or (g.available_from is not null and clock_timestamp()<g.available_from)
  or (g.available_until is not null and clock_timestamp()>=g.available_until) then
  raise exception 'Gift is outside its availability window; no coins charged' using errcode='22023';
 end if;
 if g.min_vip_tier>0 then
  select case when p.vip_expires_at>clock_timestamp() then p.vip_level else 0 end into v_level
   from public.profiles p where p.id=new.sender_id;
  if coalesce(v_level,0)<g.min_vip_tier then
   raise exception 'Gift membership requirement not met; no coins charged' using errcode='22023';
  end if;
 end if;
 return new;
end $$;
revoke all on function nimzo_internal.guard_gift_availability() from public,anon,authenticated;
create trigger nimzo_guard_gift_availability before insert on public.gift_events
 for each row execute function nimzo_internal.guard_gift_availability();
commit;

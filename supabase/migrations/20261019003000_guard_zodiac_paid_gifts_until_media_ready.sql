-- Libra/Aries paid-gift safety gate. Does not touch any users, existing
-- receipts or balances. Prevents activating/billing either zodiac gift until
-- approved playable HTTPS VAP media metadata exists on the server.
-- Insertion into gift_events occurs in the same atomic transaction as the
-- coin deduction in send_gift / send_profile_gift / send_moment_gift.
create or replace function nimzo_private.require_zodiac_gift_media_ready()
returns trigger
language plpgsql
security definer
set search_path = ''
as $func$
declare
  v_gift uuid;
begin
  if TG_TABLE_NAME = 'gifts' then
    if coalesce(NEW.active, false) = false then
      return NEW;
    end if;
    v_gift := NEW.id;
  elsif TG_TABLE_NAME = 'gift_events' then
    v_gift := NEW.gift_id;
  else
    return NEW;
  end if;

  -- No behavior change for any existing gifts or Hall of Fame.
  if v_gift is null or v_gift not in (
    '1178a55b-ebed-59a6-9c6a-efb24893b59b'::uuid,
    '1245657f-3156-5724-a601-e2f5c5fd2e35'::uuid
  ) then
    return NEW;
  end if;

  if not exists (
    select 1
    from public.gift_animation_media m
    where m.gift_id = v_gift
      and m.approved is true
      and m.duration_ms between 5000 and 10000
      and m.video_url ~* '^https://[^[:space:]/]+/[^[:space:]]+'
  ) then
    raise exception 'Zodiac gift animation not approved; no coins charged'
      using errcode='P0001';
  end if;

  return NEW;
end
$func$;

revoke all on function nimzo_private.require_zodiac_gift_media_ready()
from public, anon, authenticated;

drop trigger if exists zodiac_gift_activation_requires_media on public.gifts;
create trigger zodiac_gift_activation_requires_media
before insert or update of active on public.gifts
for each row execute function nimzo_private.require_zodiac_gift_media_ready();

drop trigger if exists zodiac_gift_purchase_requires_media on public.gift_events;
create trigger zodiac_gift_purchase_requires_media
before insert on public.gift_events
for each row execute function nimzo_private.require_zodiac_gift_media_ready();

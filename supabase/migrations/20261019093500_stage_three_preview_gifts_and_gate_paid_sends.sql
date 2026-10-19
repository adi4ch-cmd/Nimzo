-- NIMZO preview catalog identity reservation; user-visible preview cards remain
-- explicitly non-sendable until licensed, alpha-composited videos are approved.
-- Never mark these active, upload unlicensed media, or alter wallet balances.
insert into public.gifts (id,name,category,coin_price,asset_path,min_vip,min_svip,active)
values
 ('fa1bc74b-02e0-5d55-9dc1-e71d451c335f','Romantic Blossom','premium',500000,'assets/gifts/staged/romantic_blossom.svg',0,0,false),
 ('a7e8f51d-4bcc-572c-a341-d49b2c3161dc','Ice Queen Magic','premium',500000,'assets/gifts/staged/ice_queen_magic.svg',0,0,false),
 ('dbe66ab1-6b9c-5326-9b79-155d4d14e3d7','Tiger Warrior','premium',500000,'assets/gifts/staged/tiger_warrior.svg',0,0,false)
on conflict (id) do nothing;

-- Expand the existing atomic purchase/activation guard to include all five
-- staged gifts. Existing triggers on gifts / gift_events are preserved.
create or replace function nimzo_private.require_zodiac_gift_media_ready()
returns trigger
language plpgsql
security definer
set search_path = ''
as $gift_guard$
declare v_gift uuid;
begin
  if TG_TABLE_NAME = 'gifts' then
    if coalesce(NEW.active,false) = false then return NEW; end if;
    v_gift := NEW.id;
  elsif TG_TABLE_NAME = 'gift_events' then
    v_gift := NEW.gift_id;
  else
    return NEW;
  end if;

  if v_gift is null or v_gift not in (
    '1178a55b-ebed-59a6-9c6a-efb24893b59b'::uuid,
    '1245657f-3156-5724-a601-e2f5c5fd2e35'::uuid,
    'fa1bc74b-02e0-5d55-9dc1-e71d451c335f'::uuid,
    'a7e8f51d-4bcc-572c-a341-d49b2c3161dc'::uuid,
    'dbe66ab1-6b9c-5326-9b79-155d4d14e3d7'::uuid
  ) then
    return NEW;
  end if;
  if not exists(
    select 1 from public.gift_animation_media m
    where m.gift_id = v_gift
    and m.approved is true
    and m.duration_ms between 1000 and 30000
    and m.video_url ~* '^https://[^[:space:]/]+/[^[:space:]]+'
  ) then
    raise exception 'Gift animation not approved; no coins charged'
    using errcode='P0001';
  end if;
  return NEW;
end
$gift_guard$;
revoke all on function nimzo_private.require_zodiac_gift_media_ready()
from public,anon,authenticated;
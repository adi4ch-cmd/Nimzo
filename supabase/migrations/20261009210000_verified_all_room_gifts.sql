-- Announce every settled room gift, including inexpensive non-Dragon gifts.
-- No change to user accounts, prices, wallet movements or existing events.
create or replace function public.record_verified_gift_animation()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare v_price bigint; v_country text; v_owner uuid; v_scope text;
begin
 if new.room_id is null or new.quantity is null or new.quantity <= 0
    or new.total_coins is null or new.total_coins <= 0 then return new; end if;
 if new.total_coins % new.quantity <> 0 then return new; end if;
 v_price := new.total_coins / new.quantity;
 select r.owner_id, nullif(upper(trim(r.country)),'') into v_owner,v_country
 from public.rooms r where r.id=new.room_id;
 if v_owner is null then return new; end if;
 if v_country is null then
   select nullif(upper(trim(p.country_code)),'') into v_country
   from public.profiles p where p.id=v_owner;
 end if;
 v_scope := case when v_price in (35000000,50000000) then 'country' else 'room' end;
 if v_scope='country' and v_country is null then return new; end if;
 insert into public.gift_animation_events
 (gift_event_id,room_id,sender_id,receiver_id,gift_id,unit_price,quantity,country_code,scope)
 values(new.id,new.room_id,new.sender_id,new.receiver_id,new.gift_id,
        v_price,new.quantity,coalesce(v_country,''),v_scope)
 on conflict (gift_event_id) do nothing;
 return new;
end $function$;
revoke all on function public.record_verified_gift_animation() from public,anon,authenticated,service_role;

-- Authenticated room members may resolve the immutable Top 1 gifter snapshot
-- at the instant each six-stage verified Rocket milestone was reached.
-- Read-only; no coins, levels, settled gift records or purchase grants changed.
create or replace function public.room_rocket_event_winner(p_event uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
 v_blast public.room_diamond_blast_events%rowtype;
 v_winner jsonb;
begin
 select * into v_blast from public.room_diamond_blast_events where id=p_event;
 if not found then return null; end if;
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not nimzo_private.room_diamond_is_member(v_blast.room_id) then
   raise exception 'room membership required' using errcode='42501';
 end if;
 with ranked as (
   select g.sender_id, sum(g.total_coins)::bigint as sent_coins
   from public.gift_events g
   where g.room_id=v_blast.room_id and g.sender_id is not null
     and g.total_coins>0
     and g.created_at>=v_blast.cycle_start
     and g.created_at<=v_blast.created_at
   group by g.sender_id
   order by sent_coins desc, g.sender_id
   limit 1
 )
 select jsonb_build_object(
   'user_id',p.id,
   'nimzo_id',p.nimzo_id,
   'name',coalesce(nullif(p.display_name,''),p.username,'Nimzo user'),
   'avatar_path',p.avatar_path,
   'gifted_coins',r.sent_coins)
 into v_winner from ranked r join public.profiles p on p.id=r.sender_id;
 return v_winner;
end;$$;
revoke all on function public.room_rocket_event_winner(uuid) from public,anon,authenticated,service_role;
grant execute on function public.room_rocket_event_winner(uuid) to authenticated;

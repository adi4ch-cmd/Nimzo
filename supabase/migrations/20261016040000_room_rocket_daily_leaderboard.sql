-- Read-only daily Rocket podium. The existing six-stage settlement and
-- wallet/ledger rewards are intentionally unchanged.
-- A room member may see Top 1-3 contributors for that room's active Saudi-day
-- cycle; ranks come only from persisted, settled gift_events.
create or replace function public.room_rocket_leaderboard(p_room uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cycle timestamptz := nimzo_private.room_diamond_cycle_start(statement_timestamp());
  v_leaders jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not nimzo_private.room_diamond_is_member(p_room) then
    raise exception 'room membership required' using errcode = '42501';
  end if;

  with totals as (
    select e.sender_id as user_id,
           sum(e.total_coins)::bigint as gifted_coins
    from public.gift_events e
    where e.room_id = p_room
      and e.created_at >= v_cycle
      and e.created_at < v_cycle + interval '24 hours'
      and e.sender_id is not null
      and e.total_coins > 0
    group by e.sender_id
  ), placed as (
    select user_id, gifted_coins,
           row_number() over (order by gifted_coins desc, user_id)::integer as place
    from totals
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'rank', t.place,
      'user_id', p.id,
      'nimzo_id', p.nimzo_id,
      'display_name', coalesce(nullif(p.display_name, ''), p.username, 'Nimzo user'),
      'avatar_path', p.avatar_path,
      'gifted_coins', t.gifted_coins
    )
    order by t.place
  ), '[]'::jsonb)
  into v_leaders
  from placed t
  join public.profiles p on p.id = t.user_id
  where t.place between 1 and 3;

  return jsonb_build_object(
    'cycle_start', v_cycle,
    'leaders', v_leaders
  );
end;
$$;
revoke all on function public.room_rocket_leaderboard(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.room_rocket_leaderboard(uuid) to authenticated;

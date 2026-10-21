-- Read-only ranking projection over settled gift ledger entries. Preserve all
-- wallet/account balances and private financial table grants. Existing weekly
-- and monthly windows remain rolling 7/30 days; daily is rolling 24 hours.
create or replace function public.leaderboard(
  p_kind text, p_period text, p_limit integer default 10
)
returns table(id uuid, name text, score bigint)
language plpgsql stable security definer
set search_path = ''
as $function$
declare
  since timestamptz;
  result_limit integer := coalesce(p_limit, 10);
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_kind is null or p_kind not in ('wealth', 'charm', 'room') then
    raise exception 'unsupported ranking kind' using errcode = '22023';
  end if;
  if p_period is null or p_period not in ('daily', 'weekly', 'monthly', 'all_time') then
    raise exception 'unsupported ranking period' using errcode = '22023';
  end if;
  if result_limit < 1 or result_limit > 100 then
    raise exception 'ranking limit must be between 1 and 100' using errcode = '22023';
  end if;
  since := case p_period
    when 'daily' then now() - interval '1 day'
    when 'weekly' then now() - interval '7 days'
    when 'monthly' then now() - interval '30 days'
    else '-infinity'::timestamptz
  end;
  if p_kind = 'wealth' then
    return query
      select p.id, p.display_name, sum(-l.coin_delta)::bigint
      from public.ledger l join public.profiles p on p.id = l.user_id
      where l.kind in ('gift_sent', 'profile_gift_sent', 'moment_gift_sent')
        and l.coin_delta < 0 and l.created_at >= since and l.created_at <= now()
        and p.status = 'active'
      group by p.id order by 3 desc, p.id asc limit result_limit;
  elsif p_kind = 'charm' then
    -- Use actual credited diamonds, including paid self gifts and the historical
    -- settlement adjustment. Do not infer credits from the current gift price
    -- or recalculate old settlement policy; exchanges/topups never contribute.
    return query
      select p.id, p.display_name, sum(l.diamond_delta)::bigint
      from public.ledger l join public.profiles p on p.id = l.user_id
      where l.kind in ('gift_received', 'profile_gift_received',
                       'moment_gift_received', 'self_gift_45pct_adjustment')
        and l.diamond_delta > 0 and l.created_at >= since and l.created_at <= now()
        and p.status = 'active'
      group by p.id order by 3 desc, p.id asc limit result_limit;
  else
    return query
      select r.id, r.name, sum(g.total_coins)::bigint
      from public.gift_events g join public.rooms r on r.id = g.room_id
      where g.total_coins > 0 and g.created_at >= since and g.created_at <= now()
      group by r.id order by 3 desc, r.id asc limit result_limit;
  end if;
end
$function$;
revoke all on function public.leaderboard(text, text, integer) from public, anon;
grant execute on function public.leaderboard(text, text, integer) to authenticated;

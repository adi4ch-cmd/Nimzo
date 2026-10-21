-- Original NIMZO milestones, version 1. Read-only recognition: no purchases,
-- rewards, entitlement rows, balance updates, or restoration of retired medals.
create function public.my_honor_milestones() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare uid uuid := auth.uid(); result jsonb;
begin
  if uid is null then raise invalid_authorization_specification using message='not authenticated'; end if;
  if not exists(select 1 from public.profiles where id=uid and status='active')
    then raise insufficient_privilege using message='account unavailable'; end if;
  with gift_sends as (
    select id::text event_id,created_at at,total_coins::numeric coins
    from public.gift_events where sender_id=uid and receiver_id<>uid and total_coins>0 and created_at<=now()
  ), rounds as (
    select b.round_id::text event_id,
      min(coalesce(b.settled_at,r.settled_at)) at,
      bool_or(b.status='won') won
    from public.game_bets b join public.game_rounds r on r.id=b.round_id
    where b.user_id=uid and b.status in ('won','lost') and r.status='settled' and coalesce(b.settled_at,r.settled_at)<=now()
    group by b.round_id
  ), events(metric,event_id,at,amount) as (
    select 'gift_sends',event_id,at,1::numeric from gift_sends
    union all select 'gift_coins',event_id,at,coins from gift_sends
    union all select 'gift_diamonds',id::text,created_at,diamond_delta::numeric
      from public.ledger where user_id=uid and kind in ('gift_received','profile_gift_received','moment_gift_received')
      and diamond_delta>0 and ref->>'from' is not null and ref->>'from'<>uid::text and created_at<=now()
    union all select 'rounds',event_id,at,1::numeric from rounds
    union all select 'wins',event_id,at,1::numeric from rounds where won
    union all select 'rooms',id::text,created_at,1::numeric from public.rooms where owner_id=uid and created_at<=now()
  ), running as (
    select *,sum(amount) over(partition by metric order by at nulls last,event_id rows unbounded preceding) cumulative
    from events
  ), totals as (
    select metric,greatest(0,sum(amount)) progress from events group by metric
  ), rules(position,code,title,category,description,metric,target) as (values
    (1,'first_gift','First gift','Giving','Send a room gift to another member.','gift_sends',1),
    (2,'gifts_10','Thoughtful sender','Giving','Complete 10 room gift sends to other members.','gift_sends',10),
    (3,'gifts_100','Community giver','Giving','Complete 100 room gift sends to other members.','gift_sends',100),
    (4,'gift_coins_1000','Generous spirit','Giving','Send room gifts worth 1,000 coins to other members.','gift_coins',1000),
    (5,'first_gift_diamonds','First appreciation','Appreciation','Receive at least one credited gift diamond from another member.','gift_diamonds',1),
    (6,'gift_diamonds_1000','Warm welcome','Appreciation','Receive 1,000 credited gift diamonds from other members.','gift_diamonds',1000),
    (7,'gift_diamonds_10000','Community favorite','Appreciation','Receive 10,000 credited gift diamonds from other members.','gift_diamonds',10000),
    (8,'rounds_1','First round','Games','Complete one distinct settled game round.','rounds',1),
    (9,'rounds_10','Ten rounds','Games','Complete 10 distinct settled game rounds.','rounds',10),
    (10,'rounds_100','Seasoned player','Games','Complete 100 distinct settled game rounds.','rounds',100),
    (11,'wins_1','First winning round','Games','Complete a settled round with a bet recorded as won.','wins',1),
    (12,'room_owner','Room creator','Community','Own a NIMZO room.','rooms',1)
  )
  select jsonb_agg(jsonb_build_object(
    'code',r.code,'title',r.title,'category',r.category,'description',r.description,
    'progress',coalesce(t.progress,0),'target',r.target,
    'earned',coalesce(t.progress,0)>=r.target,
    'earned_at',case when coalesce(t.progress,0)>=r.target then
      (select min(h.at) from running h where h.metric=r.metric and h.cumulative>=r.target) end
  ) order by r.position) into result
  from rules r left join totals t on t.metric=r.metric;
  return result;
end $$;
revoke all on function public.my_honor_milestones() from public,anon;
grant execute on function public.my_honor_milestones() to authenticated;
comment on function public.my_honor_milestones() is
'Original NIMZO milestone rules v1, computed from retained actual records for the signed-in active user; no rewards or persisted medal entitlement.';

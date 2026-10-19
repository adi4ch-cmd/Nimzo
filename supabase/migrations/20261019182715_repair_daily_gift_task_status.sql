-- The daily task must survive leaving a room without exposing payment history.
create or replace function nimzo_private.my_daily_room_gift_status()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_start timestamptz := date_trunc('day', statement_timestamp() at time zone 'UTC') at time zone 'UTC';
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if not exists (select 1 from public.profiles where id = v_user and status = 'active') then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  return exists (
    select 1 from public.gift_events
    where sender_id = v_user and room_id is not null
      and total_coins > 0 and created_at >= v_start
      and created_at < v_start + interval '1 day'
  );
end;
$$;

create or replace function public.my_daily_room_gift_status()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select nimzo_private.my_daily_room_gift_status(); $$;

revoke all on function nimzo_private.my_daily_room_gift_status() from public, anon;
revoke all on function public.my_daily_room_gift_status() from public, anon;
grant usage on schema nimzo_private to authenticated;
grant execute on function nimzo_private.my_daily_room_gift_status() to authenticated;
grant execute on function public.my_daily_room_gift_status() to authenticated;

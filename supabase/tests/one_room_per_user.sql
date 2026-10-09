-- Run read-only after applying 20261009052036_permanent_room_owner_guard.sql to staging.
-- This does not create/delete rooms or touch user accounts or balances.
do $$
declare
  owner_constraint_count integer;
  guard_count integer;
begin
  select count(*) into owner_constraint_count
  from pg_constraint
  where conrelid = 'public.rooms'::regclass
    and conname = 'rooms_one_per_owner'
    and contype = 'u';

  if owner_constraint_count <> 1 then
    raise exception 'One room per owner unique constraint missing';
  end if;

  select count(*) into guard_count
  from pg_trigger
  where tgrelid = 'public.rooms'::regclass
    and tgname = 'nimzo_room_owner_number_guard'
    and not tgisinternal;

  if guard_count <> 1 then
    raise exception 'Room number enforcement trigger missing';
  end if;

  if exists (
    select 1 from public.rooms group by owner_id having count(*) > 1
  ) then
    raise exception 'A user owns more than one room';
  end if;

  if exists (
    select 1 from public.rooms r
    join public.profiles p on p.id = r.owner_id
    where r.room_no is distinct from p.nimzo_id
  ) then
    raise exception 'Room ID differs from permanent Nimzo user ID';
  end if;
end $$;

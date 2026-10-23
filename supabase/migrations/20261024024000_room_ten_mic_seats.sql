-- NIMZO voice room contract: five microphones per row, two rows.
-- Keep existing user rooms and occupied seats 1..10 unchanged.
-- If any seat 11..15 is occupied, abort instead of evicting its user.
lock table public.mic_seats in access exclusive mode;

do $$
declare
  definition text;
  item record;
begin
  if exists (
    select 1 from public.mic_seats
    where seat_no > 10 and user_id is not null
  ) then
    raise exception 'Cannot reduce mic seats: a seat above 10 is occupied';
  end if;

  for item in
    select * from (values
      ('public.create_room(text,text,text)', 'generate_series(1,15)', 'generate_series(1,10)'),
      ('public.take_seat(uuid,integer)', 'p_seat>15', 'p_seat>10'),
      ('public.mod_assign_seat(uuid,integer,uuid)', 'p_seat not between 1 and 15', 'p_seat not between 1 and 10'),
      ('public.mod_lock_seat(uuid,integer,boolean)', 'p_seat not between 1 and 15', 'p_seat not between 1 and 10'),
      ('public.mod_mute_seat(uuid,integer,boolean)', 'p_seat not between 1 and 15', 'p_seat not between 1 and 10')
    ) as changes(signature, old_token, new_token)
  loop
    definition := pg_get_functiondef(to_regprocedure(item.signature));
    if definition is null or strpos(definition, item.old_token) = 0 then
      raise exception 'Unexpected room function definition: %', item.signature;
    end if;
    execute replace(definition, item.old_token, item.new_token);
  end loop;
end;
$$;

delete from public.mic_seats where seat_no > 10;
alter table public.mic_seats drop constraint mic_seats_seat_no_check;
alter table public.mic_seats
  add constraint mic_seats_seat_no_check check (seat_no between 1 and 10);

-- All new rooms now create 10 seats; all seat RPCs reject seat 11+.

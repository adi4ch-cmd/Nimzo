-- Ensure every existing and future Nimzo room has exactly the ten-seat structure.
insert into public.mic_seats(room_id,seat_no)
select r.id,g
from public.rooms r
cross join generate_series(1,10) g
on conflict (room_id,seat_no) do nothing;

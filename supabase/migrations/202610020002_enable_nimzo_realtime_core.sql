-- Nimzo realtime channels used by the app.
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.room_members;
alter publication supabase_realtime add table public.mic_seats;
alter publication supabase_realtime add table public.room_messages;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.gift_events;
alter publication supabase_realtime add table public.wallets;
alter publication supabase_realtime add table public.game_round_events;

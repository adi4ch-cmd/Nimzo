-- Nimzo production security/performance hardening.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS fn
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f'
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon', r.fn);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.current_week_period(timestamptz) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.game_config(text) TO anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked_id ON public.blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee_id ON public.follows(followee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee_id ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_game_bets_game_id ON public.game_bets(game_id);
CREATE INDEX IF NOT EXISTS idx_game_round_events_game_id ON public.game_round_events(game_id);
CREATE INDEX IF NOT EXISTS idx_game_round_events_user_id ON public.game_round_events(user_id);
CREATE INDEX IF NOT EXISTS idx_gift_events_gift_id ON public.gift_events(gift_id);
CREATE INDEX IF NOT EXISTS idx_gift_events_receiver_id ON public.gift_events(receiver_id);
CREATE INDEX IF NOT EXISTS idx_gift_events_room_id ON public.gift_events(room_id);
CREATE INDEX IF NOT EXISTS idx_gift_events_sender_id ON public.gift_events(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_mic_seats_user_id ON public.mic_seats(user_id);
CREATE INDEX IF NOT EXISTS idx_moment_comments_author_id ON public.moment_comments(author_id);
CREATE INDEX IF NOT EXISTS idx_moment_comments_moment_id ON public.moment_comments(moment_id);
CREATE INDEX IF NOT EXISTS idx_moment_likes_user_id ON public.moment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_moments_author_id ON public.moments(author_id);

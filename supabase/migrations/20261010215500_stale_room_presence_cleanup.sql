-- Server-side stale voice room membership recovery.
-- Never deletes auth.users, profiles, rooms, wallet/ledger or gifts.
-- New NIMZO builds heartbeat every 70s while inside the room. A member
-- absent for 15 minutes is no longer counted as present or seated.
BEGIN;
CREATE INDEX IF NOT EXISTS room_members_presence_heartbeat_idx
  ON public.room_members (activity_credited_until);

CREATE OR REPLACE FUNCTION nimzo_private.expire_stale_room_members()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE
  v_cutoff timestamptz := pg_catalog.statement_timestamp() - interval '15 minutes';
  v_row record;
  v_cleared integer := 0;
  v_seats integer := 0;
  v_count integer;
BEGIN
  -- SKIP LOCKED avoids blocking join/leave/heartbeat transactions.
  FOR v_row IN
    SELECT room_id,user_id
      FROM public.room_members
     WHERE activity_credited_until < v_cutoff
     ORDER BY activity_credited_until
     FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      -- Same row lock serializes against touch_room_activity.
      UPDATE public.mic_seats
         SET user_id=NULL,muted=false
       WHERE room_id=v_row.room_id AND user_id=v_row.user_id;
      GET DIAGNOSTICS v_count = ROW_COUNT;
      v_seats := v_seats + v_count;

      DELETE FROM public.room_members
       WHERE room_id=v_row.room_id AND user_id=v_row.user_id
         AND activity_credited_until < v_cutoff;
      GET DIAGNOSTICS v_count = ROW_COUNT;
      v_cleared := v_cleared + v_count;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Room presence cleanup deferred one stale row (SQLSTATE %)',SQLSTATE;
    END;
  END LOOP;
  RETURN pg_catalog.jsonb_build_object(
    'stale_members_removed',v_cleared,'stale_seats_released',v_seats,
    'grace_minutes',15);
END;
$fn$;
REVOKE ALL ON FUNCTION nimzo_private.expire_stale_room_members()
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION nimzo_private.expire_stale_room_members()
  TO postgres;
-- Periodic recovery when device dies before its authenticated leave RPC.
SELECT cron.schedule(
  'nimzo-room-presence-expiry',
  '*/5 * * * *',
  'SELECT nimzo_private.expire_stale_room_members();'
);
COMMIT;
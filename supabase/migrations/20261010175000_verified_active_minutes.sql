-- Count actual room-presence minutes at server time only. No client
-- supplied points, duration, or membership IDs; no coin/wallet changes.
BEGIN;
ALTER TABLE public.room_members
 ADD COLUMN IF NOT EXISTS activity_credited_until timestamptz
 NOT NULL DEFAULT pg_catalog.now();

CREATE OR REPLACE FUNCTION public.touch_room_activity(p_room uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $f$
DECLARE
 v_user uuid := auth.uid();
 v_since timestamptz;
 v_now timestamptz := pg_catalog.statement_timestamp();
 v_minutes integer;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
 SELECT activity_credited_until INTO v_since FROM public.room_members
 WHERE room_id=p_room AND user_id=v_user FOR UPDATE;
 IF NOT FOUND THEN RETURN 0; END IF;
 v_minutes := LEAST(2,GREATEST(0,
   FLOOR(EXTRACT(EPOCH FROM (v_now-v_since)) / 60)::integer));
 IF v_minutes<=0 THEN RETURN 0; END IF;
 UPDATE public.profiles
   SET active_points = COALESCE(active_points,0) + v_minutes
   WHERE id=v_user AND status='active';
 IF NOT FOUND THEN RETURN 0; END IF;
 UPDATE public.room_members
 SET activity_credited_until=v_now
 WHERE room_id=p_room AND user_id=v_user;
 RETURN v_minutes;
END;
$f$;
REVOKE ALL ON FUNCTION public.touch_room_activity(uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.touch_room_activity(uuid)
 TO authenticated;

-- Prevent clients forging timestamps. SECURITY DEFINER RPC updates only
-- the caller's own room membership; no direct UPDATE grant is introduced.
REVOKE UPDATE(activity_credited_until) ON public.room_members
 FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
-- Read-only receipt recovery must precede mutable room/game eligibility checks.
-- Never create a round, change a balance, reveal another account or accept a
-- changed retry payload. The existing play_game economics stay unchanged.
begin;
create function public.my_game_receipt(p_room uuid,p_game text,p_bet bigint,p_key text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); b public.game_bets; slug text;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if p_room is null or p_game is null or p_game not in ('fruit_party','fruit_wheel') or p_bet is null or p_bet<1 or p_bet>500000
 or nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'INVALID_GAME_RECEIPT_REQUEST' using errcode='22023';end if;
 select * into b from public.game_bets where user_id=u and client_key=p_key;
 if not found then return jsonb_build_object('status','missing');end if;
 select g.slug into slug from public.game_catalog g where g.id=b.game_id;
 if slug is distinct from p_game or b.bet_amount is distinct from p_bet or b.bet_type is distinct from 'spin'
 or b.selection is not null or (b.room_id is not null and b.room_id is distinct from p_room) then
  raise exception 'GAME_RECEIPT_PAYLOAD_MISMATCH' using errcode='22023';
 end if;
 if b.status not in ('won','lost') or b.settled_at is null then raise exception 'GAME_SETTLEMENT_UNCONFIRMED';end if;
 return jsonb_build_object('duplicate',true,'bet_id',b.id,'round_id',b.round_id,'game',slug,
   'bet',b.bet_amount,'status',b.status,'payout',b.payout_amount,'result',b.result_payload);
end$$;
revoke all on function public.my_game_receipt(uuid,text,bigint,text) from public,anon,authenticated;
grant execute on function public.my_game_receipt(uuid,text,bigint,text) to authenticated;
create function public.play_game_checked(p_room uuid,p_game_slug text,p_bet_amount bigint,p_client_key text,p_expected_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); receipt jsonb;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if p_expected_user is distinct from u then raise exception 'GAME_ACCOUNT_CHANGED' using errcode='22023';end if;
 if nullif(trim(p_client_key),'') is null or length(p_client_key)>200 then raise exception 'INVALID_GAME_RECEIPT_REQUEST' using errcode='22023';end if;
 -- Same lock as play_game: wait for an in-flight settlement before deciding
 -- that a receipt is absent, including across room/catalog changes.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('game:'||u::text||':'||p_client_key,0));
 receipt:=public.my_game_receipt(p_room,p_game_slug,p_bet_amount,p_client_key);
 if receipt->>'status'<>'missing' then return receipt;end if;
 return public.play_game(p_game_slug,p_bet_amount,'spin',null,p_client_key,p_room);
end$$;
revoke all on function public.play_game_checked(uuid,text,bigint,text,uuid) from public,anon,authenticated;
grant execute on function public.play_game_checked(uuid,text,bigint,text,uuid) to authenticated;
notify pgrst,'reload schema';
commit;

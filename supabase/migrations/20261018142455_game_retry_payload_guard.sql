-- Preserve existing game RNG, odds, caps and payouts; bind retries to original input.
alter table public.game_bets add column room_id uuid references public.rooms(id) on delete set null;
create index game_bets_room_id on public.game_bets(room_id);
grant select(room_id) on public.game_bets to authenticated;
CREATE OR REPLACE FUNCTION public.play_game(p_game_slug text, p_bet_amount bigint, p_bet_type text DEFAULT 'spin'::text, p_selection text DEFAULT NULL::text, p_client_key text DEFAULT NULL::text, p_room uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms;
  v_game public.game_catalog;
  v_round public.game_rounds;
  v_bet public.game_bets;
  v_wallet public.wallets;
  v_seed text;
  v_hash text;
  v_index integer;
  v_symbol text;
  v_multiplier numeric;
  v_payout bigint := 0;
  v_grid jsonb;
  v_roll bigint;
  v_i integer;
  v_j integer;
  v_symbols text[] := array['watermelon','lemon','orange','grape','plum','bell','gem','7'];
  v_counts jsonb := '{}'::jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from profiles where id=v_uid and status='active') then raise exception 'ACCOUNT_RESTRICTED'; end if;
  if p_room is null then select room_id into p_room from room_members where user_id=v_uid; end if;
  select * into v_room from rooms where id=p_room and status='open' for share;
  if not found or not exists(select 1 from room_members where room_id=p_room and user_id=v_uid) or exists(select 1 from room_bans where room_id=p_room and user_id=v_uid) then raise exception 'ROOM_MEMBERSHIP_REQUIRED'; end if;
  if not v_room.perm_game or not room_allows(p_room,v_uid,v_room.game_permission) then raise exception 'ROOM_GAME_DISABLED'; end if;
  if p_bet_amount is null or p_bet_amount <= 0 then raise exception 'INVALID_BET'; end if;
  if p_bet_amount > 500000 then raise exception 'BET_LIMIT_EXCEEDED'; end if;

  if nullif(trim(p_client_key),'') is null or length(p_client_key)>200 then raise exception 'idempotency key required';end if;
  perform pg_advisory_xact_lock(hashtextextended('game:'||v_uid::text||':'||p_client_key,0));

  select * into v_game from public.game_catalog where slug=p_game_slug and active for update;
  if not found then raise exception 'GAME_NOT_FOUND'; end if;

  if p_client_key is not null then
    select * into v_bet from public.game_bets
    where user_id=v_uid and client_key=p_client_key
    limit 1;
    if found then
      if v_bet.game_id is distinct from v_game.id or v_bet.bet_amount is distinct from p_bet_amount
       or v_bet.bet_type is distinct from p_bet_type or v_bet.selection is distinct from p_selection
       or (v_bet.room_id is not null and v_bet.room_id is distinct from p_room) then
        raise exception 'idempotency payload mismatch';
      end if;
      return jsonb_build_object('duplicate',true,'bet_id',v_bet.id,'status',v_bet.status,
        'payout',v_bet.payout_amount,'result',v_bet.result_payload);
    end if;
  end if;

  select * into v_wallet from public.wallets where user_id=v_uid for update;
  if not found then raise exception 'WALLET_NOT_FOUND'; end if;
  if v_wallet.coins < p_bet_amount then raise exception 'INSUFFICIENT_COINS'; end if;

  update public.wallets set coins=coins-p_bet_amount where user_id=v_uid;

  insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  values(v_uid,'game_bet',-p_bet_amount,0,
    jsonb_build_object('game',p_game_slug,'bet_type',p_bet_type,'selection',p_selection),
    coalesce('game-bet:'||p_client_key,'game-bet:'||gen_random_uuid()::text));

  v_seed := encode(gen_random_bytes(32),'hex');
  v_hash := encode(digest(v_seed,'sha256'),'hex');

  insert into public.game_rounds(game_id,status,server_seed_hash,server_seed)
  values(v_game.id,'settled',v_hash,v_seed)
  returning * into v_round;

  if p_game_slug='fruit_wheel' then
    v_roll := ('x'||substr(encode(digest(v_seed||v_uid::text||coalesce(p_client_key,''),'sha256'),'hex'),1,8))::bit(32)::bigint;
    v_index := (abs(v_roll) % 20)+1;
    select symbol,multiplier into v_symbol,v_multiplier
    from public.game_wheel_segments
    where game_id=v_game.id and segment_no=v_index and active;
    v_payout := floor(p_bet_amount*v_multiplier);
    v_grid := jsonb_build_object('segment',v_index,'symbol',v_symbol,'multiplier',v_multiplier);
  elsif p_game_slug='fruit_party' then
    v_grid := '[]'::jsonb;
    for v_i in 1..5 loop
      for v_j in 1..5 loop
        v_roll := ('x'||substr(encode(digest(v_seed||v_i::text||':'||v_j::text,'sha256'),'hex'),1,8))::bit(32)::bigint;
        v_symbol := v_symbols[(abs(v_roll) % array_length(v_symbols,1))+1];
        v_grid := v_grid || jsonb_build_array(v_symbol);
      end loop;
    end loop;
    v_counts := jsonb_build_object();
    for v_symbol in select jsonb_array_elements_text(v_grid) loop
      v_counts := jsonb_set(v_counts,array[v_symbol],to_jsonb(coalesce((v_counts->>v_symbol)::int,0)+1),true);
    end loop;
    -- Configurable baseline: 5+ matching symbols pays 2x, 8+ pays 3x, 12+ pays 5x.
    v_payout := case
      when greatest(coalesce((v_counts->>'watermelon')::int,0),coalesce((v_counts->>'lemon')::int,0),coalesce((v_counts->>'orange')::int,0),coalesce((v_counts->>'grape')::int,0),coalesce((v_counts->>'plum')::int,0),coalesce((v_counts->>'bell')::int,0),coalesce((v_counts->>'gem')::int,0),coalesce((v_counts->>'7')::int,0)) >= 12 then p_bet_amount*5
      when greatest(coalesce((v_counts->>'watermelon')::int,0),coalesce((v_counts->>'lemon')::int,0),coalesce((v_counts->>'orange')::int,0),coalesce((v_counts->>'grape')::int,0),coalesce((v_counts->>'plum')::int,0),coalesce((v_counts->>'bell')::int,0),coalesce((v_counts->>'gem')::int,0),coalesce((v_counts->>'7')::int,0)) >= 8 then p_bet_amount*3
      when greatest(coalesce((v_counts->>'watermelon')::int,0),coalesce((v_counts->>'lemon')::int,0),coalesce((v_counts->>'orange')::int,0),coalesce((v_counts->>'grape')::int,0),coalesce((v_counts->>'plum')::int,0),coalesce((v_counts->>'bell')::int,0),coalesce((v_counts->>'gem')::int,0),coalesce((v_counts->>'7')::int,0)) >= 5 then p_bet_amount*2
      else 0 end;
  else
    raise exception 'UNSUPPORTED_GAME';
  end if;

  if v_payout > 0 then
    update public.wallets set coins=coins+v_payout where user_id=v_uid;
    insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
    values(v_uid,'game_win',v_payout,0,jsonb_build_object('game',p_game_slug,'round_id',v_round.id,'payout',v_payout),
      'game-win:'||v_round.id::text);
  end if;

  update public.game_rounds
  set result_symbol=v_symbol,result_index=v_index,
      result_payload=case when p_game_slug='fruit_wheel' then v_grid else jsonb_build_object('grid',v_grid,'counts',v_counts,'payout',v_payout) end,
      settled_at=now()
  where id=v_round.id;

  insert into public.game_bets(room_id,round_id,game_id,user_id,bet_type,selection,bet_amount,payout_amount,status,client_key,result_payload,settled_at)
  values(p_room,v_round.id,v_game.id,v_uid,p_bet_type,p_selection,p_bet_amount,v_payout,
    case when v_payout>0 then 'won' else 'lost' end,p_client_key,
    case when p_game_slug='fruit_wheel' then v_grid else jsonb_build_object('grid',v_grid,'counts',v_counts) end,now())
  returning * into v_bet;

  insert into public.game_round_events(round_id,game_id,user_id,event_type,payload)
  values(v_round.id,v_game.id,v_uid,'settled',
    jsonb_build_object('bet_id',v_bet.id,'bet',p_bet_amount,'payout',v_payout,'server_seed_hash',v_hash));

  return jsonb_build_object(
    'bet_id',v_bet.id,'round_id',v_round.id,'game',p_game_slug,
    'bet',p_bet_amount,'payout',v_payout,
    'status',v_bet.status,'result',v_bet.result_payload,
    'server_seed',v_seed,'server_seed_hash',v_hash
  );
end;
$function$;

notify pgrst,'reload schema';

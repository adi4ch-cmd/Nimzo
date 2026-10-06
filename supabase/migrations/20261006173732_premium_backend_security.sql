-- Non-destructive premium repair. Fail on duplicate legacy rows rather than deleting them.
-- Transactions/IDs/balances remain authoritative. Existing counters are derived from retained records.
alter table public.rooms add column if not exists lifetime_gift_coins bigint not null default 0;
alter table public.moments add column if not exists lifetime_gift_coins bigint not null default 0;
alter table public.moments add column if not exists lifetime_likes bigint not null default 0;
alter table public.moments add column if not exists lifetime_comments bigint not null default 0;
alter table public.profiles add column if not exists wealth_coins bigint not null default 0;
alter table public.profiles add column if not exists charm_diamonds bigint not null default 0;
alter table public.profiles add column if not exists active_points bigint not null default 0;
revoke insert,update,delete on public.profiles from public,anon,authenticated;
-- Revoke any old per-column UPDATE grants as well as table grants.
do $$ declare c record; begin for c in select column_name from information_schema.columns where table_schema='public' and table_name='profiles' loop execute format('revoke update (%I) on public.profiles from public, anon, authenticated',c.column_name); end loop; end $$;
grant update(username,display_name,bio,avatar_path,cover_path,country_code,country_name,language,gender,date_of_birth,last_seen) on public.profiles to authenticated;
revoke insert,update,delete on public.rooms from public,anon,authenticated;
revoke select on public.rooms from public,anon,authenticated;
grant select(id,room_no,owner_id,name,country,theme,is_private,status,created_at,rules,mic_permission,chat_permission,guest_permission,gift_permission,music_permission,game_permission,visitor_permission,perm_mic,perm_chat,perm_guest,perm_gift,perm_music,perm_game,perm_visitor,last_active,avatar_path,lifetime_gift_coins) on public.rooms to authenticated;
create unique index if not exists rooms_one_open_per_owner on public.rooms(owner_id) where status='open';
create unique index if not exists mic_seats_one_per_user on public.mic_seats(user_id) where user_id is not null;
create unique index if not exists room_members_one_room_per_user on public.room_members(user_id);
create table public.room_moderators(room_id uuid not null references public.rooms(id),user_id uuid not null references public.profiles(id),primary key(room_id,user_id));
insert into public.room_moderators select room_id,user_id from public.room_members where role='moderator' on conflict do nothing;
alter table public.room_moderators enable row level security;
revoke all on public.room_moderators from public,anon,authenticated;
create or replace function public.can_moderate(p_room uuid,p_uid uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$ select exists(select 1 from rooms where id=p_room and owner_id=p_uid) or exists(select 1 from room_moderators where room_id=p_room and user_id=p_uid) or exists(select 1 from admins where user_id=p_uid) $$;
create or replace function public.set_moderator(p_room uuid,p_user uuid,p_on boolean) returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then raise exception 'only the owner can manage moderators'; end if; if p_on then insert into room_moderators values(p_room,p_user) on conflict do nothing; else delete from room_moderators where room_id=p_room and user_id=p_user; end if; update room_members set role=case when p_on then 'moderator' else 'member' end where room_id=p_room and user_id=p_user; end $$;
create or replace function public.clear_room_chat(p_room uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin if auth.uid() is null then raise exception 'not authenticated'; end if; delete from room_messages where room_id=p_room and user_id=auth.uid(); end $$;
create or replace function public.leave_room(p_room uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin if auth.uid() is null then raise exception 'not authenticated'; end if; perform 1 from profiles where id=auth.uid() for update; update mic_seats set user_id=null,muted=false where room_id=p_room and user_id=auth.uid(); perform clear_room_chat(p_room); delete from room_members where room_id=p_room and user_id=auth.uid(); end $$;
CREATE OR REPLACE FUNCTION public.join_room(p_room uuid, p_password text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare r public.rooms;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists(select 1 from public.room_members where user_id=auth.uid() and room_id<>p_room) then
    raise exception 'leave your current room first';
  end if;
  perform 1 from public.profiles where id=auth.uid() and status='active' for update;
  if not found then raise exception 'account restricted'; end if;
  select * into r from public.rooms where id=p_room and status='open';
  if not found then raise exception 'room unavailable'; end if;
  if exists(select 1 from public.room_bans where room_id=p_room and user_id=auth.uid()) then raise exception 'banned from room'; end if;
  if r.is_private and r.owner_id<>auth.uid() and (p_password is null or r.password_hash is distinct from crypt(p_password,r.password_hash)) then
    raise exception 'wrong password (password required)';
  end if;
  insert into public.room_members(room_id,user_id,role) values(p_room,auth.uid(),case when exists(select 1 from room_moderators where room_id=p_room and user_id=auth.uid()) then 'moderator' else 'member' end) on conflict do nothing;
  update public.rooms set last_active=now() where id=p_room;
end $function$;
CREATE OR REPLACE FUNCTION public.create_room(p_name text, p_country text, p_password text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare rid uuid; v_nimzo bigint;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform 1 from public.profiles where id=auth.uid() for update;
  if exists(select 1 from public.room_members where user_id=auth.uid()) then raise exception 'leave your current room first'; end if;
  if exists(select 1 from public.rooms where owner_id=auth.uid() and status='open') then
    raise exception 'you already have an open room';
  end if;
  if nullif(trim(coalesce(p_name,'')),'') is null then raise exception 'room name is required'; end if;
  if length(trim(p_name)) > 40 then raise exception 'room name is too long'; end if;

  select nimzo_id into v_nimzo
  from public.profiles
  where id=auth.uid() and status='active';

  if v_nimzo is null then raise exception 'profile unavailable'; end if;
  if exists(select 1 from public.rooms where room_no=v_nimzo) then
    raise exception 'room number already exists for this user';
  end if;

  insert into public.rooms(room_no,owner_id,name,country,is_private,password_hash)
  values (
    v_nimzo, auth.uid(), trim(p_name),
    nullif(trim(coalesce(p_country,'')),''),
    coalesce(p_password,'')<>'',
    case when coalesce(p_password,'')<>'' then crypt(p_password,gen_salt('bf')) end
  )
  returning id into rid;

  insert into public.mic_seats(room_id,seat_no)
  select rid,g from generate_series(1,10) g
  on conflict (room_id,seat_no) do nothing;

  insert into public.room_members(room_id,user_id,role)
  values(rid,auth.uid(),'member')
  on conflict do nothing;

  return rid;
end
$function$;
CREATE OR REPLACE FUNCTION public.take_seat(p_room uuid, p_seat integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare r rooms;begin if auth.uid() is null then raise exception 'not authenticated'; end if; perform 1 from profiles where id=auth.uid() and status='active' for update; if not found then raise exception 'account restricted'; end if; select * into r from rooms where id=p_room and status='open';if not found then raise exception'room unavailable';end if;if p_seat<1 or p_seat>10 then raise exception'bad seat';end if;if not exists(select 1 from room_members where room_id=p_room and user_id=auth.uid())then raise exception'join the room first';end if;if not r.perm_mic and not can_moderate(p_room,auth.uid())then raise exception'mic is turned off in this room';end if;if exists(select 1 from room_bans where room_id=p_room and user_id=auth.uid()) then raise exception 'banned from room'; end if; if not room_allows(p_room,auth.uid(),r.mic_permission) then raise exception 'mic permission required'; end if; if exists(select 1 from mic_seats where user_id=auth.uid() and (room_id<>p_room or seat_no<>p_seat)) then raise exception 'already seated'; end if; insert into mic_seats(room_id,seat_no)values(p_room,p_seat)on conflict do nothing;update mic_seats set user_id=auth.uid()where room_id=p_room and seat_no=p_seat and (user_id is null or user_id=auth.uid()) and not locked;if not found then raise exception'seat unavailable';end if;end $function$;
CREATE OR REPLACE FUNCTION public.send_gift(p_room uuid, p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare s uuid:=auth.uid(); owner uuid; allow_g boolean; price bigint; total bigint; diamond_credit bigint; room_credit bigint; mv int; ms int; pr profiles%rowtype;
begin
if s is null then raise exception 'not authenticated'; end if;
if p_receiver is null or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999 then raise exception 'invalid gift request'; end if;
if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'idempotency key required'; end if;
if exists(select 1 from ledger where user_id=s and idempotency_key=p_key||':sender' and kind='gift_sent') then return jsonb_build_object('status','replayed'); end if;
select owner_id,perm_gift into owner,allow_g from rooms where id=p_room and status='open';
if owner is null or not allow_g then raise exception 'room unavailable or gifts disabled'; end if;
if not exists(select 1 from room_members where room_id=p_room and user_id=s) or not exists(select 1 from room_members where room_id=p_room and user_id=p_receiver) then raise exception 'room member required'; end if;
select * into pr from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
select coin_price,min_vip,min_svip into price,mv,ms from gifts where id=p_gift and active; if price is null then raise exception 'gift unavailable'; end if;
if (case when pr.vip_expires_at>now() then coalesce(pr.vip_level,0) else 0 end)<coalesce(mv,0) or (case when pr.svip_cycle_start+interval '90 days'>now() then coalesce(pr.svip_level,0) else 0 end)<coalesce(ms,0) then raise exception 'gift tier required'; end if;
if exists(select 1 from room_bans where room_id=p_room and user_id in(s,p_receiver)) then raise exception 'banned from room'; end if;
if not room_allows(p_room,s,(select gift_permission from rooms where id=p_room)) then raise exception 'gift permission required'; end if;
total:=price*p_qty; diamond_credit:=case when s=p_receiver then 0 else total*45/100 end; room_credit:=total*5/100;
perform 1 from wallets where user_id in(s,p_receiver,owner) order by user_id for update;
update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;
if owner<>s then update wallets set coins=coins+room_credit where user_id=owner; end if;
insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(s,'gift_sent',-total,0,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty,'receiver',p_receiver),p_key||':sender'),
(p_receiver,'gift_received',0,diamond_credit,jsonb_build_object('room',p_room,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
if owner<>s then insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(owner,'room_reward',room_credit,0,jsonb_build_object('room',p_room,'rate',5),p_key||':room'); end if;
insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(p_room,s,p_receiver,p_gift,p_qty,total);
return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit,'room_coins',room_credit);
end $function$;
CREATE OR REPLACE FUNCTION public.send_moment_gift(p_moment uuid, p_receiver uuid, p_gift uuid, p_qty integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare s uuid:=auth.uid(); price bigint; total bigint; diamond_credit bigint; vip int; svip int; g gifts%rowtype;
begin
if s is null then raise exception 'not authenticated'; end if;
if p_receiver is null or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999 then raise exception 'invalid gift request'; end if;
if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'idempotency key required'; end if;
if exists(select 1 from ledger where user_id=s and idempotency_key=p_key||':sender' and kind='moment_gift_sent') then return jsonb_build_object('status','replayed'); end if;
if not exists(select 1 from moments where id=p_moment and author_id=p_receiver) then raise exception 'moment receiver mismatch'; end if;
select * into g from gifts where id=p_gift and active; if not found then raise exception 'gift unavailable'; end if;
select case when vip_expires_at>now() then vip_level else 0 end,case when svip_cycle_start+interval '90 days'>now() then svip_level else 0 end into vip,svip from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
if vip<g.min_vip or svip<g.min_svip then raise exception 'gift tier required'; end if;
price:=g.coin_price; total:=price*p_qty; diamond_credit:=case when s=p_receiver then 0 else total*45/100 end;
perform 1 from wallets where user_id in(s,p_receiver) order by user_id for update;
update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;
insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
(s,'moment_gift_sent',-total,0,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty,'receiver',p_receiver),p_key||':sender'),
(p_receiver,'moment_gift_received',0,diamond_credit,jsonb_build_object('moment',p_moment,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(null,s,p_receiver,p_gift,p_qty,total);
update moments set lifetime_gift_coins=lifetime_gift_coins+total where id=p_moment;
return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit);
end $function$;
drop function public.play_game(text,bigint,text,text,text);
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

  select * into v_game from public.game_catalog where slug=p_game_slug and active for update;
  if not found then raise exception 'GAME_NOT_FOUND'; end if;

  if p_client_key is not null then
    select * into v_bet from public.game_bets
    where user_id=v_uid and client_key=p_client_key
    limit 1;
    if found then
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

  insert into public.game_bets(round_id,game_id,user_id,bet_type,selection,bet_amount,payout_amount,status,client_key,result_payload,settled_at)
  values(v_round.id,v_game.id,v_uid,p_bet_type,p_selection,p_bet_amount,v_payout,
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
CREATE OR REPLACE FUNCTION public.reconcile_wallet(p_user uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select jsonb_build_object('user_id',p_user,'wallet_coins',w.coins,'wallet_diamonds',w.diamonds,
 'ledger_coins',coalesce((select sum(coin_delta) from ledger where user_id=p_user),0),
 'ledger_diamonds',coalesce((select sum(diamond_delta) from ledger where user_id=p_user),0))
 from wallets w where w.user_id=p_user and (p_user=auth.uid() or is_admin()) $function$;
drop view public.rooms_ranked;
create view public.rooms_ranked with (security_invoker=true) as select r.id,r.room_no,r.owner_id,r.name,r.country,r.theme,r.is_private,r.status,r.created_at,r.rules,r.mic_permission,r.chat_permission,r.guest_permission,r.gift_permission,r.music_permission,r.game_permission,r.visitor_permission,r.perm_mic,r.perm_chat,r.perm_guest,r.perm_gift,r.perm_music,r.perm_game,r.perm_visitor,r.last_active,r.avatar_path,r.lifetime_gift_coins,coalesce(mc.member_count,0)::bigint member_count,row_number() over(order by coalesce(mc.member_count,0) desc,r.last_active desc nulls last,r.created_at desc)::bigint rank from public.rooms r left join(select room_id,count(*) member_count from public.room_members group by room_id)mc on mc.room_id=r.id where r.status='open';
revoke all on public.rooms_ranked from public,anon,authenticated;
grant select on public.rooms_ranked to authenticated;
-- Persist recent rooms independently from live presence; no manufactured departed visits.
create table public.room_visit_history(room_id uuid not null references public.rooms(id),user_id uuid not null references public.profiles(id),last_joined_at timestamptz not null,primary key(room_id,user_id));
insert into public.room_visit_history select room_id,user_id,joined_at from public.room_members;
alter table public.room_visit_history enable row level security;
revoke all on public.room_visit_history from public,anon,authenticated;
grant select on public.room_visit_history to authenticated;
create policy room_visit_own on public.room_visit_history for select to authenticated using(user_id=auth.uid());
create or replace function public.track_room_visit() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$ begin new.joined_at:=clock_timestamp(); insert into room_visit_history(room_id,user_id,last_joined_at) values(new.room_id,new.user_id,new.joined_at) on conflict(room_id,user_id) do update set last_joined_at=excluded.last_joined_at; return new; end $$;
revoke all on function public.track_room_visit() from public,anon,authenticated;
create trigger track_room_visit before insert on public.room_members for each row execute function public.track_room_visit();
alter table public.room_messages alter column created_at set default clock_timestamp();
drop policy if exists room_chat_read on public.room_messages;
create policy room_chat_read on public.room_messages for select to authenticated using(exists(select 1 from public.room_members m where m.room_id=room_messages.room_id and m.user_id=auth.uid() and room_messages.created_at>=m.joined_at));
create or replace function public.my_rooms() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$ select jsonb_build_object('recent',coalesce((select jsonb_agg(to_jsonb(r)-'password_hash')from(select rooms.* from room_visit_history v join rooms on rooms.id=v.room_id where v.user_id=auth.uid() and rooms.status='open' order by v.last_joined_at desc limit 10)r),'[]'::jsonb),'followed',coalesce((select jsonb_agg(to_jsonb(r)-'password_hash')from(select rooms.* from room_follows f join rooms on rooms.id=f.room_id where f.user_id=auth.uid() and rooms.status='open' limit 20)r),'[]'::jsonb)) $$;

create table public.profile_tags(user_id uuid not null references public.profiles(id),tag text not null check(length(tag) between 1 and 40),sort_order integer not null default 0,primary key(user_id,tag));
create table public.couples(id uuid primary key default gen_random_uuid(),user_a uuid not null unique references public.profiles(id),user_b uuid not null unique references public.profiles(id),created_at timestamptz not null default now(),check(user_a<>user_b));
create table public.models(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),title text not null, image_path text,active boolean not null default true,created_at timestamptz not null default now());
create index models_user_id_idx on public.models(user_id);
do $$ declare t text; begin foreach t in array array['profile_tags','couples','models'] loop execute format('alter table public.%I enable row level security',t); execute format('revoke all on public.%I from public,anon,authenticated',t); execute format('grant select,insert,update,delete on public.%I to authenticated',t); execute format('create policy verified_read on public.%I for select to authenticated using(true)',t); execute format('create policy verified_admin_write on public.%I for all to authenticated using(public.is_admin()) with check(public.is_admin())',t); end loop; end $$;
-- Lifetime counters start with evidence retained today; deleted historical likes/comments cannot be recovered.
update rooms r set lifetime_gift_coins=(select coalesce(sum(total_coins),0) from gift_events where room_id=r.id);
update moments m set lifetime_likes=(select count(*) from moment_likes where moment_id=m.id),lifetime_comments=(select count(*) from moment_comments where moment_id=m.id),lifetime_gift_coins=(select coalesce(sum(-coin_delta),0) from ledger where kind='moment_gift_sent' and ref->>'moment'=m.id::text);
update profiles p set wealth_coins=(select coalesce(sum(total_coins),0) from gift_events where sender_id=p.id),charm_diamonds=(select coalesce(sum(diamond_delta),0) from ledger where user_id=p.id and kind in('gift_received','moment_gift_received'));
revoke update on public.moments from authenticated;
grant update(body,image_path) on public.moments to authenticated;
-- INSERT column grants also prevent clients seeding fabricated lifetime counters.
revoke insert on public.moments from authenticated;
grant insert(author_id,body,image_path) on public.moments to authenticated;
create or replace function public.track_lifetime_events() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$ begin if tg_table_name='gift_events' then update rooms set lifetime_gift_coins=lifetime_gift_coins+new.total_coins where id=new.room_id; update profiles set wealth_coins=wealth_coins+new.total_coins where id=new.sender_id; update profiles set charm_diamonds=charm_diamonds+case when new.sender_id<>new.receiver_id then new.total_coins*45/100 else 0 end where id=new.receiver_id; elsif tg_table_name='moment_likes' then update moments set lifetime_likes=lifetime_likes+1 where id=new.moment_id; elsif tg_table_name='moment_comments' then update moments set lifetime_comments=lifetime_comments+1 where id=new.moment_id; end if; return new; end $$;
create trigger track_gifts after insert on public.gift_events for each row execute function public.track_lifetime_events();
create trigger track_likes after insert on public.moment_likes for each row execute function public.track_lifetime_events();
create trigger track_comments after insert on public.moment_comments for each row execute function public.track_lifetime_events();
create or replace function public.voice_access(p_room uuid,p_user uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$ select jsonb_build_object('allowed',exists(select 1 from rooms r join room_members m on m.room_id=r.id join profiles p on p.id=m.user_id where r.id=p_room and m.user_id=p_user and r.status='open' and p.status='active' and not exists(select 1 from room_bans where room_id=p_room and user_id=p_user)),'canTransmit',exists(select 1 from rooms r join mic_seats s on s.room_id=r.id where r.id=p_room and s.user_id=p_user and not s.locked and not s.muted and (r.perm_mic or can_moderate(p_room,p_user)) and room_allows(p_room,p_user,r.mic_permission))) $$;
revoke all on function public.voice_access(uuid,uuid) from public,anon,authenticated;
grant execute on function public.voice_access(uuid,uuid) to service_role;
revoke all on function public.track_lifetime_events() from public,anon,authenticated;
revoke all on function public.play_game(text,bigint,text,text,text,uuid) from public,anon;
grant execute on function public.play_game(text,bigint,text,text,text,uuid) to authenticated,service_role;
revoke all on function public.clear_room_chat(uuid) from public,anon;
grant execute on function public.clear_room_chat(uuid) to authenticated,service_role;
notify pgrst,'reload schema';

create or replace function public.profile_gifts(p_user uuid) returns table(gift_id uuid,name text,image_path text,quantity bigint) language sql stable security definer set search_path=public,pg_temp as $$ select g.id,g.name,g.asset_path,sum(e.quantity)::bigint from gift_events e join gifts g on g.id=e.gift_id where e.receiver_id=p_user and auth.uid() is not null group by g.id,g.name,g.asset_path order by sum(e.quantity) desc $$;
revoke all on function public.profile_gifts(uuid) from public,anon;
grant execute on function public.profile_gifts(uuid) to authenticated,service_role;

-- Nimzo: self-gifts + ephemeral room chat
-- Apply to the production Supabase project.

create or replace function public.send_gift(p_room uuid, p_receiver uuid, p_gift uuid, p_qty int, p_key text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_sender uuid := auth.uid(); v_owner uuid; v_allow boolean := true;
  v_price bigint; v_total bigint; v_diamonds bigint; v_owner_coins bigint;
  v_min_vip int; v_min_svip int; v_p profiles;
begin
  if v_sender is null then raise exception 'not authenticated'; end if;
  if p_qty < 1 or p_qty > 9999 then raise exception 'bad quantity'; end if;
  if exists(select 1 from ledger where user_id=v_sender and kind='gift_sent' and idempotency_key=p_key) then
    return jsonb_build_object('status','replayed');
  end if;
  select owner_id, coalesce(perm_gift,true) into v_owner, v_allow from rooms where id=p_room and status='open';
  if v_owner is null then raise exception 'room unavailable'; end if;
  if not v_allow then raise exception 'gifts are turned off in this room'; end if;
  if p_receiver <> v_sender and not exists(select 1 from room_members where room_id=p_room and user_id=p_receiver) then raise exception 'receiver is not in this room'; end if;
  select * into v_p from profiles where id=v_sender and status='active';
  if not found then raise exception 'account restricted'; end if;
  if p_receiver <> v_sender and exists(select 1 from blocks where blocker_id=p_receiver and blocked_id=v_sender) then raise exception 'blocked'; end if;
  select coin_price,min_vip,min_svip into v_price,v_min_vip,v_min_svip from gifts where id=p_gift and active;
  if v_price is null then raise exception 'gift unavailable'; end if;
  if v_p.vip_level < v_min_vip or v_p.svip_level < v_min_svip then raise exception 'tier required'; end if;
  v_total := v_price*p_qty; v_diamonds := (v_total*45)/100; v_owner_coins := (v_total*5)/100;
  perform 1 from wallets where user_id in (v_sender,p_receiver,v_owner) order by user_id for update;
  update wallets set coins=coins-v_total where user_id=v_sender and coins>=v_total;
  if not found then raise exception 'insufficient coins'; end if;
  update wallets set diamonds=diamonds+v_diamonds where user_id=p_receiver;
  if v_owner <> v_sender then update wallets set coins=coins+v_owner_coins where user_id=v_owner; end if;
  update rooms set lifetime_gift_coins=lifetime_gift_coins+v_total where id=p_room;
  insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
    (v_sender,'gift_sent',-v_total,0,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty),p_key),
    (p_receiver,'gift_received',0,v_diamonds,jsonb_build_object('room',p_room,'from',v_sender),p_key);
  if v_owner <> v_sender then
    insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
    values(v_owner,'room_reward',v_owner_coins,0,jsonb_build_object('room',p_room),p_key);
  end if;
  insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(p_room,v_sender,p_receiver,p_gift,p_qty,v_total);
  return jsonb_build_object('status','ok','total',v_total,'diamonds',v_diamonds,'owner_coins',case when v_owner=v_sender then 0 else v_owner_coins end,'room_lifetime_gifts',v_total);
end $$;
revoke all on function public.send_gift(uuid,uuid,uuid,int,text) from public;
grant execute on function public.send_gift(uuid,uuid,uuid,int,text) to authenticated;

create or replace function public.send_moment_gift(p_moment uuid,p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
returns jsonb language plpgsql security definer set search_path=public,extensions
as $$
declare s uuid:=auth.uid(); price bigint; total bigint; diamond_credit bigint; gid uuid; pid uuid; vip int; svip int; g gifts%rowtype;
begin
 if s is null then raise exception 'not authenticated'; end if;
 if p_qty<1 or p_qty>9999 then raise exception 'bad gift request'; end if;
 if exists(select 1 from ledger where user_id=s and kind='moment_gift_sent' and idempotency_key=p_key) then return jsonb_build_object('status','replayed'); end if;
 if not exists(select 1 from moments where id=p_moment and author_id=p_receiver) then raise exception 'moment receiver mismatch'; end if;
 select * into g from gifts where id=p_gift and active;
 if not found then raise exception 'gift unavailable'; end if;
 select vip_level,svip_level into vip,svip from profiles where id=s and status='active';
 if not found then raise exception 'account restricted'; end if;
 if vip < g.min_vip or svip < g.min_svip then raise exception 'gift tier required'; end if;
 price:=g.coin_price; total:=price*p_qty; diamond_credit:=(total*45)/100;
 perform 1 from wallets where user_id in(s,p_receiver) order by user_id for update;
 update wallets w set coins=w.coins-total where w.user_id=s and w.coins>=total;
 if not found then raise exception 'insufficient coins'; end if;
 update wallets w set diamonds=w.diamonds+diamond_credit where w.user_id=p_receiver;
 update moments set lifetime_gift_coins=lifetime_gift_coins+total where id=p_moment;
 insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
 values(s,'moment_gift_sent',-total,0,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty),p_key);
 if p_receiver <> s then
   insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
   values(p_receiver,'moment_gift_received',0,diamond_credit,jsonb_build_object('moment',p_moment,'from',s),p_key);
 end if;
 insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(null,s,p_receiver,p_gift,p_qty,total) returning id into gid;
 pid:=ensure_current_week();
 insert into gift_economy_events(gift_event_id,period_id,sender_id,receiver_id,room_id,gross_coins,receiver_diamonds,host_rate,agency_rate,room_rate,reseller_rate,bd_rate,manager_rate,admin_rate,super_admin_rate,relationship_snapshot)
 values(gid,pid,s,p_receiver,null,total,diamond_credit,0,0,0,0,0,0,0,0,jsonb_build_object('moment_id',p_moment));
 return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit);
end $$;
revoke all on function public.send_moment_gift(uuid,uuid,uuid,integer,text) from public;
grant execute on function public.send_moment_gift(uuid,uuid,uuid,integer,text) to authenticated;

create or replace function public.clear_room_chat(p_room uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not exists(select 1 from room_members where room_id=p_room and user_id=auth.uid())
     and not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) then
    raise exception 'not a room member';
  end if;
  delete from room_messages where room_id=p_room;
end $$;
revoke all on function public.clear_room_chat(uuid) from public;
grant execute on function public.clear_room_chat(uuid) to authenticated;

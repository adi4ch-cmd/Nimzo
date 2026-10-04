create or replace function public.send_gift(p_room uuid,p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $function$
declare s uuid:=auth.uid(); owner uuid; allow_g boolean; price bigint; total bigint; diamond_credit bigint; room_credit bigint; mv int; ms int; p profiles;
begin
 if s is null then raise exception 'not authenticated'; end if;
 if p_receiver is null then raise exception 'receiver not selected'; end if;
 if p_qty is null or p_qty<1 or p_qty>9999 then raise exception 'invalid gift quantity'; end if;
 if p_gift is null then raise exception 'gift not selected'; end if;
 if p_key is null or length(trim(p_key))<8 then raise exception 'invalid gift request key'; end if;
 if exists(select 1 from ledger where user_id=s and kind='gift_sent' and idempotency_key=p_key) then return jsonb_build_object('status','replayed'); end if;
 select owner_id,perm_gift into owner,allow_g from rooms where id=p_room and status='open';
 if owner is null or not allow_g then raise exception 'room unavailable or gifts disabled'; end if;
 if not exists(select 1 from room_members where room_id=p_room and user_id=s) then raise exception 'sender is not in room'; end if;
 if not exists(select 1 from room_members where room_id=p_room and user_id=p_receiver) then raise exception 'receiver is not in room'; end if;
 select * into p from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
 if p_receiver<>s and exists(select 1 from blocks where blocker_id=p_receiver and blocked_id=s) then raise exception 'blocked'; end if;
 select coin_price,min_vip,min_svip into price,mv,ms from gifts where id=p_gift and active;
 if price is null then raise exception 'gift unavailable'; end if;
 if coalesce(p.vip_level,0)<coalesce(mv,0) or coalesce(p.svip_level,0)<coalesce(ms,0) then raise exception 'gift tier required'; end if;
 total:=price*p_qty; diamond_credit:=case when p_receiver=s then 0 else (total*45)/100 end; room_credit:=(total*6)/100;
 perform 1 from wallets where user_id in(s,p_receiver,owner) order by user_id for update;
 update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
 if p_receiver<>s then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;
 update wallets set coins=coins+room_credit where user_id=owner;
 insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
 (s,'gift_sent',-total,jsonb_build_object('room',p_room,'gift',p_gift,'qty',p_qty),p_key),
 (p_receiver,'gift_received',0,diamond_credit,jsonb_build_object('room',p_room,'from',s),p_key),
 (owner,'room_reward',room_credit,0,jsonb_build_object('room',p_room,'rate',6),p_key);
 insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(p_room,s,p_receiver,p_gift,p_qty,total);
 return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit,'room_coins',room_credit,'room_rate',6);
end $function$;

create or replace function public.send_moment_gift(p_moment uuid,p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $function$
declare s uuid:=auth.uid(); price bigint; total bigint; diamond_credit bigint; vip int; svip int; g gifts%rowtype;
begin
 if s is null then raise exception 'not authenticated'; end if;
 if p_receiver is null then raise exception 'receiver not selected'; end if;
 if p_qty is null or p_qty<1 or p_qty>9999 then raise exception 'invalid gift quantity'; end if;
 if p_gift is null then raise exception 'gift not selected'; end if;
 if p_key is null or length(trim(p_key))<8 then raise exception 'invalid gift request key'; end if;
 if exists(select 1 from ledger where user_id=s and kind='moment_gift_sent' and idempotency_key=p_key) then return jsonb_build_object('status','replayed'); end if;
 if not exists(select 1 from moments where id=p_moment and author_id=p_receiver) then raise exception 'moment receiver mismatch'; end if;
 select * into g from gifts where id=p_gift and active; if not found then raise exception 'gift unavailable'; end if;
 select vip_level,svip_level into vip,svip from profiles where id=s and status='active'; if not found then raise exception 'account restricted'; end if;
 if vip<g.min_vip or svip<g.min_svip then raise exception 'gift tier required'; end if;
 price:=g.coin_price; total:=price*p_qty; diamond_credit:=case when s=p_receiver then 0 else (total*45)/100 end;
 perform 1 from wallets where user_id in(s,p_receiver) order by user_id for update;
 update wallets set coins=coins-total where user_id=s and coins>=total; if not found then raise exception 'insufficient coins'; end if;
 if s<>p_receiver then update wallets set diamonds=diamonds+diamond_credit where user_id=p_receiver; end if;
 insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
 (s,'moment_gift_sent',-total,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty),p_key),
 (p_receiver,'moment_gift_received',0,diamond_credit,jsonb_build_object('moment',p_moment,'from',s),p_key);
 insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(null,s,p_receiver,p_gift,p_qty,total);
 return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit);
end $function$;

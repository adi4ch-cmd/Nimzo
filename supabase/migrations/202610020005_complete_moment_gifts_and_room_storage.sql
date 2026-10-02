begin;
drop policy if exists room_image_upload on storage.objects;
create policy room_image_upload on storage.objects for insert to authenticated
with check (bucket_id='room-images' and exists (select 1 from public.rooms r where r.id=(storage.foldername(name))[1]::uuid and r.owner_id=auth.uid()));
drop policy if exists room_image_update on storage.objects;
create policy room_image_update on storage.objects for update to authenticated
using (bucket_id='room-images' and exists (select 1 from public.rooms r where r.id=(storage.foldername(name))[1]::uuid and r.owner_id=auth.uid()))
with check (bucket_id='room-images' and exists (select 1 from public.rooms r where r.id=(storage.foldername(name))[1]::uuid and r.owner_id=auth.uid()));

create or replace function public.send_moment_gift(p_moment uuid,p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
returns jsonb language plpgsql security definer set search_path=public,extensions
as $function$
declare s uuid:=auth.uid(); price bigint; total bigint; diamond_credit bigint; gid uuid; pid uuid; vip int; svip int; g gifts%rowtype;
begin
 if s is null then raise exception 'not authenticated'; end if;
 if p_qty<1 or p_qty>9999 or s=p_receiver then raise exception 'bad gift request'; end if;
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
 insert into ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
 values(s,'moment_gift_sent',-total,jsonb_build_object('moment',p_moment,'gift',p_gift,'qty',p_qty),p_key),
 (p_receiver,'moment_gift_received',0,diamond_credit,jsonb_build_object('moment',p_moment,'from',s),p_key);
 insert into gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins) values(null,s,p_receiver,p_gift,p_qty,total) returning id into gid;
 pid:=ensure_current_week();
 insert into gift_economy_events(gift_event_id,period_id,sender_id,receiver_id,room_id,gross_coins,receiver_diamonds,host_rate,agency_rate,room_rate,reseller_rate,bd_rate,manager_rate,admin_rate,super_admin_rate,relationship_snapshot)
 values(gid,pid,s,p_receiver,null,total,diamond_credit,0,0,0,0,0,0,0,0,jsonb_build_object('moment_id',p_moment));
 return jsonb_build_object('status','ok','total',total,'diamonds',diamond_credit);
end $function$;
revoke all on function public.send_moment_gift(uuid,uuid,uuid,integer,text) from public;
grant execute on function public.send_moment_gift(uuid,uuid,uuid,integer,text) to authenticated;
commit;
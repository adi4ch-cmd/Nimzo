-- Synthetic fixture only. Every mutation rolls back.
begin;
insert into profiles(id) values('00000000-0000-0000-0000-000000000021');
insert into wallets(user_id,coins,diamonds) values('00000000-0000-0000-0000-000000000021',1000,0);
insert into gifts(id,coin_price,active) values('10000000-0000-0000-0000-000000000021',10,false);
insert into gift_animation_media(gift_id,approved,video_url,media_kind,sha256,byte_size,mime_type,rights_reference,verified_at,device_verified_at)
 values('10000000-0000-0000-0000-000000000021',true,'https://fixture.example/'||repeat('a',64)||'.mp4','mp4',repeat('a',64),8,'video/mp4','Fictional SQL fixture only',now(),now());
update gifts set active=true,available_from=now()+interval '1 hour'
 where id='10000000-0000-0000-0000-000000000021';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000021',true);
set local role authenticated;
do $$begin
 begin perform send_profile_gift_checked(auth.uid(),'10000000-0000-0000-0000-000000000021',1,'future-window-key',10);raise exception 'future gift accepted';exception when invalid_parameter_value then null;end;
end$$;
reset role;
update gifts set available_from=null,available_until=now()-interval '1 minute'
 where id='10000000-0000-0000-0000-000000000021';
set local role authenticated;
do $$begin
 begin perform send_profile_gift_checked(auth.uid(),'10000000-0000-0000-0000-000000000021',1,'expired-window-key',10);raise exception 'expired gift accepted';exception when invalid_parameter_value then null;end;
end$$;
reset role;
update gifts set available_until=null,min_vip_tier=2 where id='10000000-0000-0000-0000-000000000021';
set local role authenticated;
do $$begin
 begin perform send_profile_gift_checked(auth.uid(),'10000000-0000-0000-0000-000000000021',1,'member-gate-key',10);raise exception 'membership bypass';exception when invalid_parameter_value then null;end;
end$$;
reset role;
update profiles set vip_level=2,vip_expires_at=now()+interval '1 day' where id=auth.uid();
set local role authenticated;
select send_profile_gift_checked(auth.uid(),'10000000-0000-0000-0000-000000000021',1,'eligible-key',10);
reset role;
update gifts set available_until=now()-interval '1 minute' where id='10000000-0000-0000-0000-000000000021';
set local role authenticated;
select send_profile_gift_checked(auth.uid(),'10000000-0000-0000-0000-000000000021',1,'eligible-key',10);
reset role;
do $$begin
 if(select coins from wallets where user_id=auth.uid())<>990 then raise exception 'unexpected charge or retry debit';end if;
 if(select count(*) from ledger where user_id=auth.uid() and kind='profile_gift_sent')<>1 then raise exception 'wrong settlement count';end if;
 raise notice 'PASS: future/expired windows, VIP eligibility, atomic rollback and replay after expiry';
end$$;
rollback;

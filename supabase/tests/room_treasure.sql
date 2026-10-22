begin;
insert into profiles(id,display_name) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'Fixture '||i from generate_series(1,9)i;
insert into wallets(user_id,coins) select id,1000000 from profiles;
insert into rooms(id) values('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
insert into room_members select '10000000-0000-0000-0000-000000000001',id from profiles where id<>'00000000-0000-0000-0000-000000000009';
insert into room_members values('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000009');
do $$declare b jsonb;r jsonb;bid uuid;v bigint;begin
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 begin perform public.create_room_treasure('10000000-0000-0000-0000-000000000001','room',10000,6,'all','wrong-account','00000000-0000-0000-0000-000000000002');raise exception 'Switched account funding accepted';exception when sqlstate '22023' then if sqlerrm<>'TREASURE_ACCOUNT_CHANGED' then raise;end if;end;
 if (select coins from wallets where user_id=auth.uid())<>1000000 then raise exception 'Switched account funding debit';end if;
 b:=public.create_room_treasure('10000000-0000-0000-0000-000000000001','room',10000,6,'all','fixture-send',auth.uid());bid:=(b->>'id')::uuid;
 if (select coins from wallets where user_id=auth.uid())<>990000 then raise exception 'Funding not debited';end if;
 r:=public.create_room_treasure('10000000-0000-0000-0000-000000000001','room',10000,6,'all','fixture-send',auth.uid());
 if r->>'id'<>b->>'id' or (select coins from wallets where user_id=auth.uid())<>990000 then raise exception 'Duplicate funding';end if;
 begin perform public.create_room_treasure('10000000-0000-0000-0000-000000000001','room',50000,6,'all','fixture-send',auth.uid());raise exception 'Mismatched retry accepted';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_PAYLOAD_MISMATCH' then raise;end if;end;
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');raise exception 'Self claim';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_NOT_ELIGIBLE' then raise;end if;end;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000009',true);
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000002');raise exception 'Cross room claim';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_NOT_ELIGIBLE' then raise;end if;end;
 for i in 2..7 loop
  perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-'||lpad(i::text,12,'0'),true);
  r:=public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');
  if (r->>'coins')::int not in (1666,1667) then raise exception 'Invalid split';end if;
  perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');
 end loop;
 if (select sum(coins) from wallets)<>9000000 then raise exception 'Coin conservation failed';end if;
 if (select count(*) from public.room_treasure_claims where box_id=bid)<>6 then raise exception 'Duplicate claim';end if;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');raise exception 'Overclaim';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_UNAVAILABLE' then raise;end if;end;
 -- Partially claimed box returns only its remaining escrow, exactly once.
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 b:=public.create_room_treasure('10000000-0000-0000-0000-000000000001','room',10000,6,'fans','fixture-refund',auth.uid());bid:=(b->>'id')::uuid;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');raise exception 'Nonfan claim';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_NOT_ELIGIBLE' then raise;end if;end;
 insert into follows values(auth.uid(),'00000000-0000-0000-0000-000000000001');
 perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');
 update public.room_treasure_boxes set expires_at=now()-interval '1 second' where id=bid;
 perform public.refund_expired_room_treasures();perform public.refund_expired_room_treasures();
 if (select sum(coins) from wallets)<>9000000 then raise exception 'Refund inflated coins';end if;
 if (select count(*) from ledger where kind='treasure_refund')<>1 then raise exception 'Duplicate refund';end if;
 -- World box can be claimed from a different joined room.
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 b:=public.create_room_treasure('10000000-0000-0000-0000-000000000001','world',500000,6,'all','fixture-world',auth.uid());bid:=(b->>'id')::uuid;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000009',true);
 if not exists(select 1 from jsonb_array_elements(public.list_room_treasures('10000000-0000-0000-0000-000000000002'))x where x->>'id'=bid::text) then raise exception 'World box hidden';end if;
 perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000002');
 -- On-mic eligibility follows actual seat state, not a client toggle.
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 b:=public.create_room_treasure('10000000-0000-0000-0000-000000000001','room',10000,6,'on_mic','fixture-mic',auth.uid());bid:=(b->>'id')::uuid;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');raise exception 'Audience claimed mic box';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_NOT_ELIGIBLE' then raise;end if;end;
 insert into mic_seats values('10000000-0000-0000-0000-000000000001',auth.uid(),true);
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');raise exception 'Locked seat claimed';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_NOT_ELIGIBLE' then raise;end if;end;
 update mic_seats set locked=false;
 insert into room_bans values('10000000-0000-0000-0000-000000000001',auth.uid());
 begin perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');raise exception 'Banned member claimed';exception when sqlstate 'P0001' then if sqlerrm<>'TREASURE_NOT_ELIGIBLE' then raise;end if;end;
 delete from room_bans;
 perform public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000001');
 -- Receipt recovery must survive expiry and leaving the room.
 update public.room_treasure_boxes set expires_at=now()-interval '1 second' where id=bid;
 delete from room_members where user_id=auth.uid();
 r:=public.claim_room_treasure(bid,'10000000-0000-0000-0000-000000000002');
 if r->>'status'<>'replayed' then raise exception 'Claim receipt lost';end if;
 perform public.refund_expired_room_treasures();
 if (select sum(coins) from wallets)+(select sum(remaining_coins) from public.room_treasure_boxes)<>9000000 then raise exception 'Wallet plus escrow conservation failed';end if;
 -- Direct table writes and cross-user claim reads are denied.
 if has_table_privilege('authenticated','public.room_treasure_boxes','INSERT') or has_table_privilege('anon','public.room_treasure_boxes','SELECT') then raise exception 'Unsafe table grant';end if;
 if has_function_privilege('authenticated','public.refund_expired_room_treasures()','EXECUTE') or has_function_privilege('anon','public.create_room_treasure(uuid,text,bigint,integer,text,text,uuid)','EXECUTE') then raise exception 'Unsafe endpoint grant';end if;
end$$;
-- Run real RLS as authenticated, not the table owner.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000009',true);
do $$begin
 if exists(select 1 from public.room_treasure_claims where user_id<>auth.uid()) then raise exception 'Other claims leaked';end if;
 if exists(select 1 from public.room_treasure_boxes where scope='room') then raise exception 'Cross-room box leaked';end if;
 begin perform client_key from public.room_treasure_boxes;raise exception 'Retry keys leaked';exception when insufficient_privilege then null;end;
 begin update public.room_treasure_boxes set remaining_coins=999999;raise exception 'Direct tampering accepted';exception when insufficient_privilege then null;end;
end$$;
reset role;
rollback;

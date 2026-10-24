begin;
insert into profiles(id,display_name,vip_level,vip_expires_at,svip_level,svip_cycle_start)
values('10000000-0000-0000-0000-000000000001','Owner',1,now()+interval '30 days',1,now()),
      ('10000000-0000-0000-0000-000000000002','Observer',0,null,0,null);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
-- Production API must exist, be authenticated, and persist a real selection.
select nimzo_membership_apply_full_set('vip',1);
do $$ declare k text; n integer; appearance jsonb; begin
 foreach k in array array['vip','svip'] loop
  for n in 1..10 loop
   update profiles set vip_level=n,svip_level=n where id=auth.uid();
   execute 'set local role authenticated';
   appearance := nimzo_membership_apply_full_set(k,n);
   if appearance->>'pack_kind'<>k or (appearance->>'pack_tier')::int<>n then raise exception 'Apply not persisted % %',k,n; end if;
   if appearance->>'primary_kind'<>k then raise exception 'Explicit selection ignored'; end if;
   if not (appearance->'pack_slots' ? 'Avatar Frame') then raise exception 'Partial full set'; end if;
   execute 'reset role';
   perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
   execute 'set local role authenticated';
   appearance := nimzo_membership_appearance('10000000-0000-0000-0000-000000000001');
   if appearance->>'pack_kind'<>k or (appearance->>'pack_tier')::int<>n then raise exception 'Observer sees different set'; end if;
   execute 'reset role';
   perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
   perform nimzo_membership_remove_full_set();
   if nimzo_membership_appearance(auth.uid())->>'pack_kind' is not null then raise exception 'Remove failed'; end if;
  end loop;
 end loop;
end $$;
update profiles set vip_level=5,svip_level=6 where id=auth.uid();
set local role authenticated;
do $$ begin
 begin perform nimzo_membership_apply_full_set('vip',4); raise exception 'Mismatched entitlement allowed'; exception when insufficient_privilege then null; end;
 begin perform nimzo_membership_apply_full_set('svip',5); raise exception 'Mismatched SVIP allowed'; exception when insufficient_privilege then null; end;
 begin perform nimzo_membership_apply_full_set('vip',11); raise exception 'Invalid tier allowed'; exception when invalid_parameter_value then null; end;
 begin update nimzo_membership_equipment set tier=10; raise exception 'Client wrote pack directly'; exception when insufficient_privilege then null; end;
 if nimzo_membership_appearance(auth.uid())->>'primary_kind'<>'svip' then raise exception 'Default SVIP priority failed'; end if;
end $$;
select nimzo_membership_apply_full_set('vip',5);
do $$ begin
 if exists(select 1 from nimzo_store_visual_equipment(array[auth.uid()]) where category='Avatar Frame') then raise exception 'Store frame not masked by full set'; end if;
end $$;
reset role;
insert into nimzo_cosmetic_catalog values('manual-frame','Avatar Frame',true);
insert into nimzo_cosmetic_ownership values(auth.uid(),'manual-frame',null);
set local role authenticated;
select nimzo_store_equip_free('manual-frame');
do $$ begin
 if nimzo_membership_appearance(auth.uid())->'pack_slots' ? 'Avatar Frame' then raise exception 'Manual frame override ignored'; end if;
 if not (nimzo_membership_appearance(auth.uid())->'pack_slots' ? 'Chat Bubble') then raise exception 'Override removed other slots'; end if;
 if not exists(select 1 from nimzo_store_visual_equipment(array[auth.uid()]) where item_id='manual-frame') then raise exception 'Manual Store frame invisible'; end if;
end $$;
select nimzo_membership_apply_full_set('vip',5);
do $$ begin
 if not (nimzo_membership_appearance(auth.uid())->'pack_slots' ? 'Avatar Frame') then raise exception 'Reapply did not restore full set'; end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from nimzo_cosmetic_equipped)<>1 or (select count(*) from nimzo_cosmetic_ownership)<>1 then raise exception 'Apply destroyed Store data'; end if;
end $$;
-- Room wallpaper never follows mere entitlement or full apply automatically.
insert into rooms(id,owner_id) values('20000000-0000-0000-0000-000000000001',auth.uid());
grant select on rooms to authenticated;
update profiles set vip_level=6 where id=auth.uid();
set local role authenticated;
select nimzo_membership_apply_full_set('vip',6);
do $$ begin
 if nimzo_membership_room_appearance('20000000-0000-0000-0000-000000000001') is not null then raise exception 'Wallpaper applied implicitly'; end if;
end $$;
select nimzo_membership_set_room_background('20000000-0000-0000-0000-000000000001',true);
do $$ begin
 if nimzo_membership_room_appearance('20000000-0000-0000-0000-000000000001')->>'tier'<>'6' then raise exception 'Owner wallpaper not persisted'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$ begin
 if nimzo_membership_room_appearance('20000000-0000-0000-0000-000000000001')->>'tier'<>'6' then raise exception 'Observer wallpaper missing'; end if;
 begin perform nimzo_membership_set_room_background('20000000-0000-0000-0000-000000000001',false); raise exception 'Other user changed owner wallpaper'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select nimzo_membership_set_room_background('20000000-0000-0000-0000-000000000001',false);
do $$ begin
 if nimzo_membership_room_appearance('20000000-0000-0000-0000-000000000001') is not null then raise exception 'Room background remove failed'; end if;
end $$;
select nimzo_membership_set_room_background('20000000-0000-0000-0000-000000000001',true);
insert into nimzo_cosmetic_catalog values('manual-room-theme','Party Theme',true);
insert into nimzo_cosmetic_ownership values(auth.uid(),'manual-room-theme',null);
set local role authenticated;
select nimzo_store_equip_free('manual-room-theme');
do $$ begin
 if nimzo_membership_room_appearance('20000000-0000-0000-0000-000000000001') is not null then raise exception 'Later manual room theme did not override membership wallpaper'; end if;
end $$;
reset role;
update profiles set vip_level=5 where id=auth.uid();
select nimzo_membership_apply_full_set('vip',5);
-- Expiration immediately hides the pack; it cannot fall back to another paid set.
update profiles set vip_expires_at=now()-interval '1 second' where id=auth.uid();
set local role authenticated;
do $$ begin
 if nimzo_membership_appearance(auth.uid())->>'pack_kind' is not null then raise exception 'Expired visuals exposed'; end if;
 if nimzo_membership_appearance(auth.uid())->>'primary_kind'<>'svip' then raise exception 'Expired identity retained'; end if;
 begin perform nimzo_membership_apply_full_set('vip',5); raise exception 'Expired apply allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
update profiles set status='blocked' where id=auth.uid();
set local role authenticated;
do $$ begin
 begin perform nimzo_membership_apply_full_set('svip',6); raise exception 'Blocked account applied'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role authenticated;
do $$ begin
 begin perform nimzo_membership_apply_full_set('vip',1); raise exception 'Anonymous apply allowed'; exception when invalid_authorization_specification then null; end;
end $$;
reset role;
rollback;

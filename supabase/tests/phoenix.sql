-- Transaction-only accounts and room. Run this entire file; fixtures always roll back.
begin;
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000006601','phoenix-a@example.invalid'),
 ('00000000-0000-4000-8000-000000006602','phoenix-b@example.invalid');
update public.profiles set vip_level=6,vip_expires_at=now()+interval '1 hour'
 where id='00000000-0000-4000-8000-000000006601';
insert into public.rooms(id,owner_id,name,room_no)
 values('00000000-0000-4000-8000-000000006603','00000000-0000-4000-8000-000000006601','Phoenix rollback check',99996603);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006601',true);
set local role authenticated;
do $$ begin
 if public.phoenix_membership(auth.uid())->>'vip_level'<>'6' then raise exception 'active VIP six rejected'; end if;
 if public.phoenix_membership('00000000-0000-4000-8000-000000006602')->>'vip_level'<>'0' then raise exception 'nonmember granted VIP'; end if;
 if public.phoenix_membership('00000000-0000-4000-8000-000000009999') is not null then raise exception 'missing profile granted'; end if;
 if has_column_privilege('authenticated','public.profiles','vip_level','update') then raise exception 'membership editable'; end if;
 if has_table_privilege('authenticated','public.phoenix_room_entries','insert') then raise exception 'entry forgery allowed'; end if;
 perform public.join_room('00000000-0000-4000-8000-000000006603');
 perform public.join_room('00000000-0000-4000-8000-000000006603');
 if (select count(*) from public.phoenix_room_entries where room_id='00000000-0000-4000-8000-000000006603')<>1 then raise exception 'join event missing or duplicate'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006602',true);
do $$ begin
 if exists(select 1 from public.phoenix_room_entries where room_id='00000000-0000-4000-8000-000000006603') then raise exception 'outsider read room events'; end if;
end $$;
reset role;
update public.profiles set vip_expires_at=now() where id='00000000-0000-4000-8000-000000006601';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006601',true);
do $$ begin
 if public.phoenix_membership(auth.uid())->>'vip_level'<>'0' then raise exception 'expiry boundary granted VIP'; end if;
end $$;
update public.profiles set vip_level=7,vip_expires_at=now()+interval '1 hour' where id='00000000-0000-4000-8000-000000006601';
do $$ begin
 if public.phoenix_membership(auth.uid())->>'vip_level'<>'7' then raise exception 'other VIP level changed'; end if;
end $$;
update public.profiles set vip_level=6,status='banned' where id='00000000-0000-4000-8000-000000006601';
do $$ begin
 if public.phoenix_membership(auth.uid())->>'vip_level'<>'0' then raise exception 'restricted profile granted VIP'; end if;
end $$;
select 'Phoenix entitlement, expiry, tier preservation, entry idempotency and RLS checks passed' as result;
rollback;

begin;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000000701','settings1@test.invalid'),('00000000-0000-4000-8000-000000000702','settings2@test.invalid');
set local role authenticated;
set local request.jwt.claim.sub='';
do $$ begin begin perform public.user_settings(); raise exception 'FAIL unauthenticated'; exception when invalid_authorization_specification then null; end; end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000701';
do $$ begin
 if public.user_settings()->>'gift_notifications'<>'true' then raise exception 'default'; end if;
 perform public.update_user_settings(false,false,false);
 if public.user_settings()->>'message_notifications'<>'false' then raise exception 'persist'; end if;
 begin perform public.update_user_settings(null,true,true); raise exception 'FAIL null accepted'; exception when invalid_parameter_value then null; end;
 begin perform public.submit_support_ticket('invalid','subject','body'); raise exception 'FAIL category'; exception when invalid_parameter_value then null; end;
 begin perform public.submit_support_ticket('bug',repeat('s',121),'body'); raise exception 'FAIL subject bound'; exception when invalid_parameter_value then null; end;
 begin perform public.submit_support_ticket('bug','subject',repeat('b',4001)); raise exception 'FAIL body bound'; exception when invalid_parameter_value then null; end;
 for i in 1..5 loop perform public.submit_support_ticket('feedback',' subject ',' body '); end loop;
 begin perform public.submit_support_ticket('feedback','subject','body'); raise exception 'FAIL rate limit'; exception when program_limit_exceeded then null; end;
 if (select count(*) from public.support_tickets)<>5 then raise exception 'owner read'; end if;
 if (select count(*) from public.support_tickets where subject='subject' and body='body')<>5 then raise exception 'trim'; end if;
 if public.request_account_deletion('reason')->>'id'<>public.request_account_deletion('again')->>'id' then raise exception 'request not idempotent'; end if;
 begin perform public.request_account_deletion(repeat('r',1001)); raise exception 'FAIL reason bound'; exception when invalid_parameter_value then null; end;
 begin insert into public.support_tickets(user_id,category,subject,body) values(auth.uid(),'bug','s','b'); raise exception 'FAIL bypass insert'; exception when insufficient_privilege then null; end;
 begin update public.user_preferences set user_id='00000000-0000-4000-8000-000000000702'; raise exception 'FAIL reassignment'; exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000702';
do $$ begin
 if (select count(*) from public.support_tickets)<>0 or (select count(*) from public.account_deletion_requests)<>0 or (select count(*) from public.user_preferences)<>0 then raise exception 'cross account row exposed'; end if;
 if public.user_settings()->>'message_notifications'<>'true' then raise exception 'cross account default'; end if;
 begin perform public.send_message('00000000-0000-4000-8000-000000000701','hello','text'); raise exception 'FAIL privacy not enforced'; exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into public.notifications(user_id,category,title,body) values('00000000-0000-4000-8000-000000000701','messages','test','body'),('00000000-0000-4000-8000-000000000701','gifts','test','body'),('00000000-0000-4000-8000-000000000701','system','test','body');
do $$ begin
 if (select count(*) from public.notifications where user_id='00000000-0000-4000-8000-000000000701')<>1 then raise exception 'notification suppression'; end if;
 if (select count(*) from public.profiles where id in ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000702'))<>2 then raise exception 'deletion request deleted profile'; end if;
end $$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000701';
select public.update_user_settings(true,true,true);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000702';
select public.send_message('00000000-0000-4000-8000-000000000701','allowed','text');
reset role;
do $$ begin if not exists(select 1 from public.messages where body='allowed') or not exists(select 1 from public.notifications where category='messages' and user_id='00000000-0000-4000-8000-000000000701') then raise exception 'reenabled preferences'; end if; end $$;
-- Real profile gift settlement and retry: notification insertion is event based.
insert into public.gifts(id,name,category,coin_price) values('00000000-0000-4000-8000-000000000703','Fixture gift','test',100);
update public.wallets set coins=10000 where user_id='00000000-0000-4000-8000-000000000702';
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000702';
select public.send_profile_gift('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000703',1,'settings-gift-on');
select public.send_profile_gift('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000703',1,'settings-gift-on');
do $$ begin
 begin perform public.respond_support_ticket((select id from public.support_tickets limit 1),'unauthorized',true); raise exception 'FAIL nonadmin response'; exception when insufficient_privilege then null; end;
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000701';
select public.update_user_settings(true,false,true);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000702';
select public.send_profile_gift('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000703',1,'settings-gift-off');
reset role;
do $$ begin
 if (select count(*) from public.notifications where category='gifts' and user_id='00000000-0000-4000-8000-000000000701')<>1 then raise exception 'gift notification replay or optout failed'; end if;
 if (select count(*) from public.gift_events where gift_id='00000000-0000-4000-8000-000000000703')<>2 then raise exception 'gift replay event count'; end if;
 if (select coins from public.wallets where user_id='00000000-0000-4000-8000-000000000702')<>9800 then raise exception 'notification changed settlement'; end if;
end $$;
-- Self-event notification follows receiver preference without inventing a gift RPC self policy.
insert into public.gift_events(sender_id,receiver_id,gift_id,quantity,total_coins) values('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000703',1,100);
do $$ begin if (select count(*) from public.notifications where category='gifts')<>1 then raise exception 'self notification optout'; end if; end $$;
insert into public.admins(user_id) values('00000000-0000-4000-8000-000000000702');
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000702';
do $$ declare ticket uuid; begin
 if (select count(*) from public.support_tickets)<>5 then raise exception 'admin cannot read tickets'; end if;
 select id into ticket from public.support_tickets limit 1;
 begin perform public.respond_support_ticket(ticket,repeat('x',4001),true); raise exception 'FAIL response bound'; exception when invalid_parameter_value then null; end;
 perform public.respond_support_ticket(ticket,' Reviewed reply ',true);
end $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000701';
do $$ begin
 if (select count(*) from public.support_tickets where response='Reviewed reply' and status='closed' and responded_at is not null)<>1 then raise exception 'owner cannot read response'; end if;
 begin update public.support_tickets set response='forged'; raise exception 'FAIL owner response write'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS settings/support auth, RLS, bounds, rate limit, persistence, privacy, notification suppression and request-only deletion';
rollback;

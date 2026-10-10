-- Private account preferences and request intake. No user/economy data is deleted.
create table public.user_preferences (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 message_notifications boolean not null default true,
 gift_notifications boolean not null default true,
 allow_messages_from_everyone boolean not null default true,
 updated_at timestamptz not null default now()
);
create table public.support_tickets (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 category text not null check(category in ('feedback','bug','account','other')),
 subject text not null check(char_length(btrim(subject)) between 1 and 120),
 body text not null check(char_length(btrim(body)) between 1 and 4000),
 response text check(response is null or char_length(btrim(response)) between 1 and 4000),
 responded_at timestamptz,
 status text not null default 'submitted' check(status in ('submitted','closed')),
 created_at timestamptz not null default now()
);
create index support_tickets_owner_created on public.support_tickets(user_id,created_at desc);
create table public.account_deletion_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 reason text not null default '' check(char_length(reason)<=1000),
 status text not null default 'requested' check(status in ('requested','cancelled','completed')),
 created_at timestamptz not null default now()
);
create unique index account_deletion_pending_owner on public.account_deletion_requests(user_id) where status='requested';
alter table public.user_preferences enable row level security;
alter table public.support_tickets enable row level security;
alter table public.account_deletion_requests enable row level security;
revoke all on public.user_preferences,public.support_tickets,public.account_deletion_requests from public,anon,authenticated;
grant select on public.user_preferences,public.support_tickets,public.account_deletion_requests to authenticated;
create policy preferences_owner_read on public.user_preferences for select to authenticated using(user_id=(select auth.uid()));
create policy tickets_owner_read on public.support_tickets for select to authenticated using(user_id=(select auth.uid()));
create policy deletion_owner_read on public.account_deletion_requests for select to authenticated using(user_id=(select auth.uid()));

create function public.user_settings() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); result jsonb;
begin
 if u is null then raise exception 'authentication required' using errcode='28000'; end if;
 select jsonb_build_object('message_notifications',message_notifications,'gift_notifications',gift_notifications,'allow_messages_from_everyone',allow_messages_from_everyone) into result from public.user_preferences where user_id=u;
 return coalesce(result,'{"message_notifications":true,"gift_notifications":true,"allow_messages_from_everyone":true}'::jsonb);
end $$;
create function public.update_user_settings(p_message_notifications boolean,p_gift_notifications boolean,p_allow_messages_from_everyone boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_message_notifications is null or p_gift_notifications is null or p_allow_messages_from_everyone is null then raise exception 'all preferences are required' using errcode='22023'; end if;
 insert into public.user_preferences(user_id,message_notifications,gift_notifications,allow_messages_from_everyone) values(u,p_message_notifications,p_gift_notifications,p_allow_messages_from_everyone)
 on conflict(user_id) do update set message_notifications=excluded.message_notifications,gift_notifications=excluded.gift_notifications,allow_messages_from_everyone=excluded.allow_messages_from_everyone,updated_at=now();
 return public.user_settings();
end $$;

-- Internal triggers enforce settings across existing and future message/gift RPCs.
create schema if not exists nimzo_private;
create function nimzo_private.apply_notification_preferences() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.user_preferences where user_id=new.user_id and ((new.category='messages' and not message_notifications) or (new.category='gifts' and not gift_notifications))) then return null; end if;
 return new;
end $$;
create trigger notification_preferences before insert on public.notifications for each row execute function nimzo_private.apply_notification_preferences();
create function nimzo_private.enforce_message_preferences() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Gift receipts must still record their settlement; only user-authored kinds are restricted.
 if new.kind in ('text','emoji','room_invite') and new.sender_id<>new.receiver_id and exists(select 1 from public.user_preferences where user_id=new.receiver_id and not allow_messages_from_everyone) then raise exception 'recipient is not accepting messages' using errcode='42501'; end if;
 return new;
end $$;
create trigger message_preferences before insert on public.messages for each row execute function nimzo_private.enforce_message_preferences();

create function public.submit_support_ticket(p_category text,p_subject text,p_body text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.support_tickets;
begin
 if u is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_category is null or p_category not in ('feedback','bug','account','other') or p_subject is null or char_length(btrim(p_subject)) not between 1 and 120 or p_body is null or char_length(btrim(p_body)) not between 1 and 4000 then raise exception 'invalid support ticket' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,719));
 if (select count(*) from public.support_tickets where user_id=u and created_at>now()-interval '1 hour')>=5 then raise exception 'support ticket rate limit reached' using errcode='54000'; end if;
 insert into public.support_tickets(user_id,category,subject,body) values(u,p_category,btrim(p_subject),btrim(p_body)) returning * into r;
 return jsonb_build_object('id',r.id,'status',r.status,'created_at',r.created_at);
end $$;
create function public.request_account_deletion(p_reason text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.account_deletion_requests;
begin
 if u is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_reason is null or char_length(p_reason)>1000 then raise exception 'invalid deletion request reason' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,720));
 select * into r from public.account_deletion_requests where user_id=u and status='requested';
 if not found then insert into public.account_deletion_requests(user_id,reason) values(u,btrim(p_reason)) returning * into r; end if;
 return jsonb_build_object('id',r.id,'status',r.status,'created_at',r.created_at);
end $$;
revoke all on function public.user_settings(),public.update_user_settings(boolean,boolean,boolean),public.submit_support_ticket(text,text,text),public.request_account_deletion(text) from public,anon;
grant execute on function public.user_settings(),public.update_user_settings(boolean,boolean,boolean),public.submit_support_ticket(text,text,text),public.request_account_deletion(text) to authenticated;
revoke all on function nimzo_private.apply_notification_preferences(),nimzo_private.enforce_message_preferences() from public,anon,authenticated;

-- One notification per new settled event, without touching balances or historical rows.
create function nimzo_private.notify_gift_event() returns trigger language plpgsql security definer set search_path='' as $$
declare gift_name text;
begin
 if new.receiver_id is null then return new; end if;
 select name into gift_name from public.gifts where id=new.gift_id;
 insert into public.notifications(user_id,category,title,body)
 values(new.receiver_id,'gifts','Gift received',left(coalesce(gift_name,'Gift')||' × '||new.quantity::text,200));
 return new;
end $$;
create trigger gift_event_notification after insert on public.gift_events for each row execute function nimzo_private.notify_gift_event();
revoke all on function nimzo_private.notify_gift_event() from public,anon,authenticated;

create policy tickets_admin_read on public.support_tickets for select to authenticated using((select public.is_admin()));
create function public.respond_support_ticket(p_ticket uuid,p_response text,p_close boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.support_tickets;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'administrator required' using errcode='42501'; end if;
 if p_ticket is null or p_response is null or char_length(btrim(p_response)) not between 1 and 4000 or p_close is null then raise exception 'invalid support response' using errcode='22023'; end if;
 update public.support_tickets set response=btrim(p_response),responded_at=now(),status=case when p_close then 'closed' else 'submitted' end where id=p_ticket returning * into r;
 if not found then raise exception 'support ticket not found' using errcode='P0002'; end if;
 return jsonb_build_object('id',r.id,'status',r.status,'response',r.response,'responded_at',r.responded_at);
end $$;
revoke all on function public.respond_support_ticket(uuid,text,boolean) from public,anon;
grant execute on function public.respond_support_ticket(uuid,text,boolean) to authenticated;

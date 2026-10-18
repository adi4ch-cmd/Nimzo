-- In-app social events only. Does not send push or award rewards.
alter table public.notifications add column actor_id uuid references public.profiles(id) on delete set null;
alter table public.notifications add column event_type text;
create index notifications_actor_id on public.notifications(actor_id);
grant select(actor_id,event_type) on public.notifications to authenticated;
create function nimzo_private.notify_social_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare actor uuid; recipient uuid; category text; event text; title text;
begin
 if TG_TABLE_NAME='follows' then
  actor=new.follower_id; recipient=new.followee_id;
  category='followers'; event='follow'; title='New follower';
 elsif TG_TABLE_NAME='friendships' then
  category='friends';
  if TG_OP='INSERT' and new.status='pending' then
   actor=new.requester_id; recipient=new.addressee_id; event='friend_request'; title='Friend request';
  elsif TG_OP='UPDATE' and new.status='accepted' and old.status is distinct from new.status then
   actor=new.addressee_id; recipient=new.requester_id; event='friend_accepted'; title='Friend request accepted';
  else return new; end if;
 elsif TG_TABLE_NAME='couple_requests' then
  category='system';
  if TG_OP='INSERT' and new.status='pending' then
   actor=new.requester_id; recipient=new.addressee_id; event='cp_request'; title='CP request';
  elsif TG_OP='UPDATE' and new.status='accepted' and old.status is distinct from new.status then
   actor=new.addressee_id; recipient=new.requester_id; event='cp_accepted'; title='CP request accepted';
  else return new; end if;
 else return new; end if;
 if actor=recipient or exists(select 1 from public.blocks where
  (blocker_id=actor and blocked_id=recipient) or (blocker_id=recipient and blocked_id=actor)) then return new; end if;
 insert into public.notifications(user_id,category,title,body,actor_id,event_type)
 values(recipient,category,title,'Open to view this activity.',actor,event);
 return new;
end $$;
revoke all on function nimzo_private.notify_social_event() from public,anon,authenticated;
create trigger notify_follow after insert on public.follows for each row execute function nimzo_private.notify_social_event();
create trigger notify_friend after insert or update of status on public.friendships for each row execute function nimzo_private.notify_social_event();
create trigger notify_cp after insert or update of status on public.couple_requests for each row execute function nimzo_private.notify_social_event();

create function nimzo_private.mark_notification_read(p_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 update public.notifications set read_at=coalesce(read_at,clock_timestamp()) where id=p_id and user_id=auth.uid();
 return found;
end $$;
revoke all on function nimzo_private.mark_notification_read(uuid) from public,anon;
grant usage on schema nimzo_private to authenticated;
grant execute on function nimzo_private.mark_notification_read(uuid) to authenticated;
create function public.mark_notification_read(p_id uuid) returns boolean
language sql security invoker set search_path='' as $$select nimzo_private.mark_notification_read(p_id)$$;
revoke all on function public.mark_notification_read(uuid) from public,anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;
notify pgrst,'reload schema';

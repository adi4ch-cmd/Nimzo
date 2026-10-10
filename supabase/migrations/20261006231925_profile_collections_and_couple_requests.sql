-- Additive profile features. No existing account, wallet, ledger or gift history is rewritten.
create table public.profile_collectibles (
 id uuid primary key default gen_random_uuid(),
 kind text not null check (kind in ('medal','frame','car')),
 name text not null check (length(trim(name)) between 1 and 100),
 image_path text not null check (length(trim(image_path)) > 0),
 description text,
 created_at timestamptz not null default now()
);
create table public.profile_owned_collectibles (
 user_id uuid not null references public.profiles(id),
 collectible_id uuid not null references public.profile_collectibles(id),
 granted_at timestamptz not null default now(),
 expires_at timestamptz,
 primary key(user_id,collectible_id),
 check (expires_at is null or expires_at > granted_at)
);
create index profile_owned_collectible_catalog on public.profile_owned_collectibles(collectible_id);
alter table public.profile_collectibles enable row level security;
alter table public.profile_owned_collectibles enable row level security;
revoke all on public.profile_collectibles,public.profile_owned_collectibles from public,anon,authenticated;
grant select,insert,update,delete on public.profile_collectibles,public.profile_owned_collectibles to authenticated;
create policy collectible_read on public.profile_collectibles for select to authenticated using(true);
create policy collectible_admin on public.profile_collectibles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy owned_collectible_read on public.profile_owned_collectibles for select to authenticated using(true);
create policy owned_collectible_admin on public.profile_owned_collectibles for all to authenticated using(public.is_admin()) with check(public.is_admin());

create table public.couple_requests (
 id uuid primary key default gen_random_uuid(),
 requester_id uuid not null references public.profiles(id),
 addressee_id uuid not null references public.profiles(id),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(),
 check(requester_id<>addressee_id)
);
create unique index couple_request_pending_pair on public.couple_requests
 (least(requester_id,addressee_id),greatest(requester_id,addressee_id)) where status='pending';
create index couple_request_inbox on public.couple_requests(addressee_id,status,created_at desc);
create index couple_request_outbox on public.couple_requests(requester_id,status,created_at desc);
alter table public.couple_requests enable row level security;
revoke all on public.couple_requests from public,anon,authenticated;
grant select,delete on public.couple_requests to authenticated;
grant insert(requester_id,addressee_id) on public.couple_requests to authenticated;
create policy couple_request_read on public.couple_requests for select to authenticated
 using((select auth.uid()) in(requester_id,addressee_id));
create policy couple_request_insert on public.couple_requests for insert to authenticated
 with check(requester_id=(select auth.uid()) and status='pending'
 and exists(select 1 from public.profiles where id=addressee_id and status='active')
 and not exists(select 1 from public.blocks where
 (blocker_id=requester_id and blocked_id=addressee_id) or
 (blocker_id=addressee_id and blocked_id=requester_id)));
create policy couple_request_cancel on public.couple_requests for delete to authenticated
 using(requester_id=(select auth.uid()) and status='pending');

create schema if not exists nimzo_private;
revoke all on schema nimzo_private from public,anon;
grant usage on schema nimzo_private to authenticated;
create function nimzo_private.respond_couple_request(p_request uuid,p_accept boolean)
 returns void language plpgsql security definer set search_path='' as $$
declare r public.couple_requests%rowtype; me uuid:=auth.uid();
begin
 if me is null or p_accept is null then raise exception 'not authenticated or invalid response'; end if;
 select * into r from public.couple_requests where id=p_request for update;
 if not found or r.addressee_id<>me or r.status<>'pending' then raise exception 'pending invitation not found'; end if;
 if p_accept then
  -- Both profile rows are locked in stable order to prevent cross-column duplicate partners.
  perform 1 from public.profiles where id in(r.requester_id,r.addressee_id) order by id for update;
  if (select count(*) from public.profiles where id in(r.requester_id,r.addressee_id) and status='active')<>2
    then raise exception 'account restricted'; end if;
  if exists(select 1 from public.blocks where
   (blocker_id=r.requester_id and blocked_id=r.addressee_id) or
   (blocker_id=r.addressee_id and blocked_id=r.requester_id)) then raise exception 'relationship unavailable'; end if;
  if exists(select 1 from public.couples where user_a in(r.requester_id,r.addressee_id)
   or user_b in(r.requester_id,r.addressee_id)) then raise exception 'a partner is already linked'; end if;
  insert into public.couples(user_a,user_b) values(r.requester_id,r.addressee_id);
 end if;
 update public.couple_requests set status=case when p_accept then 'accepted' else 'declined' end where id=r.id;
end $$;
revoke all on function nimzo_private.respond_couple_request(uuid,boolean) from public,anon;
grant execute on function nimzo_private.respond_couple_request(uuid,boolean) to authenticated;
create function public.respond_couple_request(p_request uuid,p_accept boolean)
 returns void language sql security invoker set search_path='' as $$
 select nimzo_private.respond_couple_request(p_request,p_accept)
$$;
revoke all on function public.respond_couple_request(uuid,boolean) from public,anon;
grant execute on function public.respond_couple_request(uuid,boolean) to authenticated;

-- Direct profile gifts have the same authoritative 45% receiver credit as Moment gifts.
-- No room owner is involved; client-supplied prices/balances never enter this API.
create function nimzo_private.send_profile_gift(p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare s uuid:=auth.uid(); g public.gifts%rowtype; pr public.profiles%rowtype;
 total bigint; credit bigint; old_ref jsonb;
begin
 if s is null then raise exception 'not authenticated'; end if;
 if p_receiver is null or p_receiver=s or p_gift is null or p_qty is null or p_qty<1 or p_qty>9999
  then raise exception 'invalid profile gift'; end if;
 if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'idempotency key required'; end if;
 -- Serialize the same sender/key even if concurrent retries change recipients.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(s::text||':'||p_key,0));
 select ref into old_ref from public.ledger where user_id=s and idempotency_key=p_key||':sender';
 if found then
  if old_ref->>'profile' is distinct from p_receiver::text or old_ref->>'gift' is distinct from p_gift::text
   or old_ref->>'qty' is distinct from p_qty::text then raise exception 'idempotency payload mismatch'; end if;
  return jsonb_build_object('status','replayed');
 end if;
 select * into pr from public.profiles where id=s and status='active';
 if not found then raise exception 'account restricted'; end if;
 if not exists(select 1 from public.profiles where id=p_receiver and status='active') then raise exception 'receiver unavailable'; end if;
 if exists(select 1 from public.blocks where (blocker_id=s and blocked_id=p_receiver)
  or(blocker_id=p_receiver and blocked_id=s)) then raise exception 'gift unavailable'; end if;
 select * into g from public.gifts where id=p_gift and active;
 if not found then raise exception 'gift unavailable'; end if;
 if (case when pr.vip_expires_at>now() then coalesce(pr.vip_level,0) else 0 end)<coalesce(g.min_vip,0)
  or (case when pr.svip_cycle_start+interval '90 days'>now() then coalesce(pr.svip_level,0) else 0 end)<coalesce(g.min_svip,0)
  then raise exception 'gift tier required'; end if;
 total:=g.coin_price*p_qty; credit:=total*45/100;
 perform 1 from public.wallets where user_id in(s,p_receiver) order by user_id for update;
 if (select count(*) from public.wallets where user_id in(s,p_receiver))<>2 then raise exception 'wallet unavailable'; end if;
 update public.wallets set coins=coins-total where user_id=s and coins>=total;
 if not found then raise exception 'insufficient coins'; end if;
 update public.wallets set diamonds=diamonds+credit where user_id=p_receiver;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key) values
 (s,'profile_gift_sent',-total,0,jsonb_build_object('profile',p_receiver,'gift',p_gift,'qty',p_qty),p_key||':sender'),
 (p_receiver,'profile_gift_received',0,credit,jsonb_build_object('profile',p_receiver,'from',s,'gift',p_gift,'qty',p_qty),p_key||':receiver');
 insert into public.gift_events(room_id,sender_id,receiver_id,gift_id,quantity,total_coins)
 values(null,s,p_receiver,p_gift,p_qty,total);
 return jsonb_build_object('status','ok','total',total,'diamonds',credit);
end $$;
revoke all on function nimzo_private.send_profile_gift(uuid,uuid,integer,text) from public,anon;
grant execute on function nimzo_private.send_profile_gift(uuid,uuid,integer,text) to authenticated;
create function public.send_profile_gift(p_receiver uuid,p_gift uuid,p_qty integer,p_key text)
 returns jsonb language sql security invoker set search_path='' as $$
 select nimzo_private.send_profile_gift(p_receiver,p_gift,p_qty,p_key)
$$;
revoke all on function public.send_profile_gift(uuid,uuid,integer,text) from public,anon;
grant execute on function public.send_profile_gift(uuid,uuid,integer,text) to authenticated;

-- Retained visitor rows each prove at least one visit; older repeated visits cannot be reconstructed.
alter table public.visitors add column visit_count bigint not null default 1 check(visit_count>0);
create function nimzo_private.record_visit(p_profile uuid)
 returns void language sql security definer set search_path='' as $$
 insert into public.visitors(profile_id,visitor_id)
 select p_profile,auth.uid() where auth.uid() is not null and p_profile<>auth.uid()
 on conflict(profile_id,visitor_id) do update
 set visited_at=now(),visit_count=public.visitors.visit_count+1
$$;
revoke all on function nimzo_private.record_visit(uuid) from public,anon;
grant execute on function nimzo_private.record_visit(uuid) to authenticated;
create or replace function public.record_visit(p_profile uuid)
 returns void language sql security invoker set search_path='' as $$
 select nimzo_private.record_visit(p_profile)
$$;
revoke all on function public.record_visit(uuid) from public,anon;
grant execute on function public.record_visit(uuid) to authenticated;
create function nimzo_private.profile_stats(p_user uuid)
 returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
 'followers',(select count(*) from public.follows where followee_id=p_user),
 'following',(select count(*) from public.follows where follower_id=p_user),
 'friends',(select count(*) from public.friendships where status='accepted' and p_user in(requester_id,addressee_id)),
 'visitors',(select coalesce(sum(visit_count),0) from public.visitors where profile_id=p_user),
 'moments',(select count(*) from public.moments where author_id=p_user))
 where auth.uid() is not null
$$;
revoke all on function nimzo_private.profile_stats(uuid) from public,anon;
grant execute on function nimzo_private.profile_stats(uuid) to authenticated;
create or replace function public.profile_stats(p_user uuid)
 returns jsonb language sql stable security invoker set search_path='' as $$
 select nimzo_private.profile_stats(p_user)
$$;
revoke all on function public.profile_stats(uuid) from public,anon;
grant execute on function public.profile_stats(uuid) to authenticated;

insert into storage.buckets(id,name,public) values('profile-collectibles','profile-collectibles',true);
create policy profile_collectible_upload on storage.objects for insert to authenticated
 with check(bucket_id='profile-collectibles' and public.is_admin());
create policy profile_collectible_update on storage.objects for update to authenticated
 using(bucket_id='profile-collectibles' and public.is_admin())
 with check(bucket_id='profile-collectibles' and public.is_admin());
create policy profile_collectible_select on storage.objects for select to authenticated
 using(bucket_id='profile-collectibles');

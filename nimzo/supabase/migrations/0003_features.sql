-- Moments, messages, notifications, visitors, banners, VIP/SVIP, recharge, leaderboards, storage.

alter table profiles add column if not exists svip_cycle_cents bigint not null default 0;
alter table profiles add column if not exists last_seen timestamptz;
alter table profiles add column if not exists vip_last_claim date;
alter table profiles add column if not exists svip_last_claim date;

-- ---------- tables ----------
create table moments (id uuid primary key default gen_random_uuid(), author_id uuid not null references profiles(id) on delete cascade,
  body text check (char_length(body) <= 500), image_path text, created_at timestamptz default now());
create table moment_likes (moment_id uuid references moments(id) on delete cascade, user_id uuid references profiles(id) on delete cascade, primary key(moment_id,user_id));
create table moment_comments (id uuid primary key default gen_random_uuid(), moment_id uuid references moments(id) on delete cascade,
  author_id uuid references profiles(id) on delete cascade, body text not null check (char_length(body) <= 300), created_at timestamptz default now());
create table reports (id uuid primary key default gen_random_uuid(), reporter_id uuid references profiles(id), target_type text not null,
  target_id text not null, reason text, status text default 'open', created_at timestamptz default now());
create table messages (id uuid primary key default gen_random_uuid(), sender_id uuid not null references profiles(id), receiver_id uuid not null references profiles(id),
  kind text not null default 'text' check (kind in ('text','emoji','gift','room_invite')), body text, read_at timestamptz, created_at timestamptz default now());
create index on messages (receiver_id, created_at desc);
create table notifications (id uuid primary key default gen_random_uuid(), user_id uuid not null references profiles(id) on delete cascade,
  category text not null check (category in ('messages','gifts','followers','friends','rooms','vip','svip','system')),
  title text, body text, read_at timestamptz, created_at timestamptz default now());
create table device_tokens (user_id uuid references profiles(id) on delete cascade, token text primary key, updated_at timestamptz default now());
create table visitors (profile_id uuid references profiles(id) on delete cascade, visitor_id uuid references profiles(id) on delete cascade, visited_at timestamptz default now(), primary key(profile_id,visitor_id));
create table banners (id uuid primary key default gen_random_uuid(), title text, subtitle text, image_path text, target text,
  start_at timestamptz, end_at timestamptz, sort_order int default 0, active boolean default true);
create table recharge_packages (id uuid primary key default gen_random_uuid(), product_id text unique not null, coins bigint not null check (coins>0),
  usd_cents int not null check (usd_cents>0), active boolean default true);
create table purchases (store text, txn_id text, user_id uuid references profiles(id), usd_cents int, coins bigint, created_at timestamptz default now(), primary key(store,txn_id));
create table vip_daily_rewards (level int primary key, coins bigint not null);
insert into vip_daily_rewards values (1,3000),(2,15000),(3,75000),(4,150000),(5,300000),(6,600000),(7,1200000),(8,2400000),(9,4800000),(10,9600000);
create table svip_thresholds (level int primary key, usd_cents bigint not null);
insert into svip_thresholds values (1,5000),(2,50000),(3,200000),(4,450000),(5,1000000),(6,2000000),(7,5000000),(8,10000000);
-- ASSUMPTION: Friday reward amounts are COINS. Confirm the unit.
create table svip_friday_rewards (level int primary key, coins bigint not null);
insert into svip_friday_rewards values (5,50000000),(6,100000000),(7,300000000),(8,600000000);

-- ---------- RLS ----------
alter table moments enable row level security; alter table moment_likes enable row level security; alter table moment_comments enable row level security;
alter table reports enable row level security; alter table messages enable row level security; alter table notifications enable row level security;
alter table device_tokens enable row level security; alter table visitors enable row level security; alter table banners enable row level security;
alter table recharge_packages enable row level security; alter table purchases enable row level security;
alter table vip_daily_rewards enable row level security; alter table svip_thresholds enable row level security; alter table svip_friday_rewards enable row level security;

create policy moments_read on moments for select to authenticated using (not exists(select 1 from blocks b where (b.blocker_id=author_id and b.blocked_id=auth.uid()) or (b.blocker_id=auth.uid() and b.blocked_id=author_id)));
create policy moments_ins on moments for insert to authenticated with check (author_id=auth.uid());
create policy moments_del on moments for delete to authenticated using (author_id=auth.uid() or is_admin());
create policy comments_read on moment_comments for select to authenticated using (true);
create policy comments_ins on moment_comments for insert to authenticated with check (author_id=auth.uid());
create policy reports_ins on reports for insert to authenticated with check (reporter_id=auth.uid());
create policy messages_read on messages for select to authenticated using (auth.uid() in (sender_id, receiver_id));
revoke insert, update, delete on messages, notifications, purchases from authenticated;
create policy notif_read on notifications for select to authenticated using (user_id=auth.uid());
create policy visitors_read on visitors for select to authenticated using (profile_id=auth.uid());
create policy banners_read on banners for select to authenticated using (active);
create policy packages_read on recharge_packages for select to authenticated using (active);
create policy vipcfg_read on vip_daily_rewards for select to authenticated using (true);
create policy device_own on device_tokens for select to authenticated using (user_id=auth.uid());

-- ---------- RPCs ----------
create or replace function profile_stats(p_user uuid) returns jsonb language sql stable security definer set search_path=public as $$
  select jsonb_build_object(
   'followers',(select count(*) from follows where followee_id=p_user),
   'following',(select count(*) from follows where follower_id=p_user),
   'friends',(select count(*) from friendships where status='accepted' and p_user in (requester_id,addressee_id)),
   'visitors',(select count(*) from visitors where profile_id=p_user),
   'moments',(select count(*) from moments where author_id=p_user)) $$;

create or replace function record_visit(p_profile uuid) returns void language sql security definer set search_path=public as $$
  insert into visitors(profile_id,visitor_id) select p_profile, auth.uid() where p_profile<>auth.uid()
  on conflict (profile_id,visitor_id) do update set visited_at=now() $$;

create or replace function toggle_like(p_moment uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  if exists(select 1 from moment_likes where moment_id=p_moment and user_id=auth.uid()) then
    delete from moment_likes where moment_id=p_moment and user_id=auth.uid();
  else insert into moment_likes values (p_moment, auth.uid()); end if;
end $$;

create or replace function moments_feed() returns table(id uuid, author_id uuid, body text, image_path text, created_at timestamptz, like_count bigint, comment_count bigint, liked boolean)
language sql stable security invoker set search_path=public as $$
  select m.id,m.author_id,m.body,m.image_path,m.created_at,
   (select count(*) from moment_likes l where l.moment_id=m.id),
   (select count(*) from moment_comments c where c.moment_id=m.id),
   exists(select 1 from moment_likes l where l.moment_id=m.id and l.user_id=auth.uid())
  from moments m order by m.created_at desc limit 100 $$;

create or replace function send_message(p_to uuid, p_body text, p_kind text default 'text') returns void
language plpgsql security definer set search_path=public as $$
begin
  if p_kind not in ('text','emoji','room_invite') then raise exception 'kind not allowed'; end if;  -- gift messages are created server-side by send_gift only
  if char_length(coalesce(p_body,''))=0 or char_length(p_body)>1000 then raise exception 'bad message'; end if;
  if exists(select 1 from blocks where (blocker_id=p_to and blocked_id=auth.uid()) or (blocker_id=auth.uid() and blocked_id=p_to)) then raise exception 'cannot message this user'; end if;
  insert into messages(sender_id,receiver_id,kind,body) values (auth.uid(),p_to,p_kind,p_body);
  insert into notifications(user_id,category,title,body) values (p_to,'messages','New message',left(p_body,80));
end $$;

create or replace function mark_read(p_from uuid) returns void language sql security definer set search_path=public as $$
  update messages set read_at=now() where receiver_id=auth.uid() and sender_id=p_from and read_at is null $$;

create or replace function conversation_list() returns table(other_id uuid, display_name text, last_body text, last_at timestamptz, unread bigint)
language sql stable security definer set search_path=public as $$
  with m as (select case when sender_id=auth.uid() then receiver_id else sender_id end as other, body, created_at, receiver_id, read_at
             from messages where auth.uid() in (sender_id,receiver_id))
  select distinct on (m.other) m.other, p.display_name, m.body, m.created_at,
    (select count(*) from messages x where x.sender_id=m.other and x.receiver_id=auth.uid() and x.read_at is null)
  from m join profiles p on p.id=m.other order by m.other, m.created_at desc $$;

create or replace function mark_notifications_read() returns void language sql security definer set search_path=public as $$
  update notifications set read_at=now() where user_id=auth.uid() and read_at is null $$;
create or replace function register_device(p_token text) returns void language sql security definer set search_path=public as $$
  insert into device_tokens(user_id,token) values (auth.uid(),p_token) on conflict (token) do update set user_id=auth.uid(), updated_at=now() $$;

create or replace function leaderboard(p_kind text, p_period text, p_limit int default 10) returns table(id uuid, name text, score bigint)
language plpgsql stable security definer set search_path=public as $$
declare since timestamptz := case p_period when 'monthly' then now()-interval '30 days' else now()-interval '7 days' end;
begin
  p_limit := least(greatest(p_limit,1),100);
  if p_kind='charm' then
    return query select p.id,p.display_name,sum(g.total_coins*45/100)::bigint from gift_events g join profiles p on p.id=g.receiver_id where g.created_at>=since group by p.id order by 3 desc limit p_limit;
  elsif p_kind='wealth' then
    return query select p.id,p.display_name,sum(g.total_coins)::bigint from gift_events g join profiles p on p.id=g.sender_id where g.created_at>=since group by p.id order by 3 desc limit p_limit;
  elsif p_kind='room' then
    return query select r.id,r.name,sum(g.total_coins)::bigint from gift_events g join rooms r on r.id=g.room_id where g.created_at>=since group by r.id order by 3 desc limit p_limit;
  else raise exception 'bad kind'; end if;
end $$;

create or replace function weekly_star() returns jsonb language sql stable security definer set search_path=public as $$
  select to_jsonb(t) from (select * from leaderboard('charm','weekly',1)) t $$;

create or replace function vip_status() returns jsonb language sql stable security definer set search_path=public as $$
  select jsonb_build_object('vip_level', case when vip_expires_at>now() then vip_level else 0 end, 'vip_expires_at', vip_expires_at,
    'svip_level', case when svip_cycle_start is not null and svip_cycle_start+interval '90 days'>now() then svip_level else 0 end) from profiles where id=auth.uid() $$;

create or replace function claim_vip_daily() returns void language plpgsql security definer set search_path=public as $$
declare p profiles; c bigint;
begin
  select * into p from profiles where id=auth.uid() for update;
  if p.vip_level=0 or p.vip_expires_at is null or p.vip_expires_at<=now() then raise exception 'no active VIP'; end if;
  if p.vip_last_claim=current_date then raise exception 'already claimed today'; end if;
  select coins into c from vip_daily_rewards where level=p.vip_level;
  update wallets set coins=coins+c where user_id=p.id;
  update profiles set vip_last_claim=current_date where id=p.id;
  insert into ledger(user_id,kind,coin_delta,idempotency_key) values (p.id,'vip_daily',c,'vip-'||current_date);
end $$;

create or replace function claim_svip_friday() returns void language plpgsql security definer set search_path=public as $$
declare p profiles; c bigint;
begin
  select * into p from profiles where id=auth.uid() for update;
  if extract(isodow from now())<>5 then raise exception 'available on Fridays'; end if;
  if p.svip_cycle_start is null or p.svip_cycle_start+interval '90 days'<=now() then raise exception 'no active SVIP'; end if;
  select coins into c from svip_friday_rewards where level=p.svip_level;
  if c is null then raise exception 'no Friday reward for your level'; end if;
  if p.svip_last_claim=current_date then raise exception 'already claimed'; end if;
  update wallets set coins=coins+c where user_id=p.id;
  update profiles set svip_last_claim=current_date where id=p.id;
  insert into ledger(user_id,kind,coin_delta,idempotency_key) values (p.id,'svip_friday',c,'svip-'||current_date);
end $$;

-- SERVER ONLY: called by the verify-purchase Edge Function (service_role) after store verification.
create or replace function apply_recharge(p_user uuid, p_store text, p_txn text, p_product text) returns void
language plpgsql security definer set search_path=public as $$
declare pk recharge_packages; p profiles; lvl int;
begin
  if exists(select 1 from purchases where store=p_store and txn_id=p_txn) then return; end if;   -- idempotent
  select * into pk from recharge_packages where product_id=p_product and active;
  if not found then raise exception 'unknown product'; end if;
  insert into purchases values (p_store,p_txn,p_user,pk.usd_cents,pk.coins);
  update wallets set coins=coins+pk.coins where user_id=p_user;
  insert into ledger(user_id,kind,coin_delta,ref,idempotency_key) values (p_user,'recharge',pk.coins,jsonb_build_object('store',p_store),p_store||':'||p_txn);
  select * into p from profiles where id=p_user for update;
  if p.svip_cycle_start is not null and p.svip_cycle_start+interval '90 days'<=now() then
    update profiles set svip_cycle_start=null, svip_cycle_cents=0, svip_level=0 where id=p_user; p.svip_cycle_cents:=0; p.svip_cycle_start:=null;
  end if;
  p.svip_cycle_cents := p.svip_cycle_cents + pk.usd_cents;
  if p.svip_cycle_start is null and p.svip_cycle_cents>=5000 then p.svip_cycle_start:=now(); end if;  -- cycle starts at first qualifying recharge
  select coalesce(max(level),0) into lvl from svip_thresholds where usd_cents<=p.svip_cycle_cents;
  update profiles set svip_cycle_cents=p.svip_cycle_cents, svip_cycle_start=p.svip_cycle_start,
    svip_level=case when p.svip_cycle_start is null then 0 else lvl end where id=p_user;
end $$;
revoke all on function apply_recharge from public, authenticated, anon;   -- service_role only

create or replace function activate_vip(p_user uuid, p_level int) returns void language sql security definer set search_path=public as $$
  update profiles set vip_level=p_level, vip_expires_at=now()+interval '30 days' where id=p_user $$;
revoke all on function activate_vip from public, authenticated, anon;      -- service_role only; VIP price not defined in spec

create or replace function admin_reports() returns setof reports language plpgsql security definer set search_path=public as $$
begin if not is_admin() then raise exception 'not allowed'; end if; return query select * from reports order by created_at desc limit 200; end $$;

revoke all on function profile_stats, record_visit, toggle_like, send_message, mark_read, conversation_list, mark_notifications_read, register_device,
  leaderboard, weekly_star, vip_status, claim_vip_daily, claim_svip_friday, admin_reports from public;
grant execute on function profile_stats, record_visit, toggle_like, moments_feed, send_message, mark_read, conversation_list, mark_notifications_read,
  register_device, leaderboard, weekly_star, vip_status, claim_vip_daily, claim_svip_friday, admin_reports to authenticated;

-- ---------- storage buckets ----------
insert into storage.buckets(id,name,public) values ('avatars','avatars',true),('covers','covers',true),('room_themes','room_themes',true),
 ('room_backgrounds','room_backgrounds',true),('gifts','gifts',true),('moments','moments',true),('banners','banners',true),('game_assets','game_assets',true)
on conflict do nothing;
-- Users write only inside their own folder (<uid>/...) for user-content buckets.
create policy user_upload on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars','covers','moments') and (storage.foldername(name))[1]=auth.uid()::text);
create policy user_update_own on storage.objects for update to authenticated
  using (bucket_id in ('avatars','covers','moments') and (storage.foldername(name))[1]=auth.uid()::text);
-- gifts, banners, room_themes, room_backgrounds, game_assets: admin/service_role only (no user policy).

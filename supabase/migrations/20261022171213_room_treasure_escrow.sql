-- Funded coin transfers only: no RNG, minting, gift/XP accrual or Rocket triggers.
begin;
create schema if not exists nimzo_private;
create table public.room_treasure_boxes(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.wallets(user_id),
 room_id uuid not null references public.rooms(id),
 scope text not null check(scope in ('room','world')),
 eligibility text not null check(eligibility in ('all','fans','on_mic')),
 total_coins bigint not null check(total_coins between 10000 and 10000000),
 quantity integer not null check(quantity in (6,10,20,30)),
 claimed_count integer not null default 0,
 remaining_coins bigint not null,
 refunded_coins bigint not null default 0,
 client_key text not null check(length(client_key) between 1 and 200),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '24 hours'),
 refunded_at timestamptz,
 unique(sender_id,client_key),
 check(claimed_count between 0 and quantity),
 check(remaining_coins between 0 and total_coins),
 check(refunded_coins between 0 and total_coins),
 check(scope<>'world' or eligibility<>'on_mic')
);
create index room_treasure_room_time on public.room_treasure_boxes(room_id,created_at desc);
create index room_treasure_world_time on public.room_treasure_boxes(created_at desc) where scope='world';
create index room_treasure_due on public.room_treasure_boxes(expires_at,id) where remaining_coins>0 and refunded_at is null;
create table public.room_treasure_claims(
 box_id uuid not null references public.room_treasure_boxes(id),
 user_id uuid not null references public.wallets(user_id),
 coins bigint not null check(coins>0),
 claimed_at timestamptz not null default now(),
 primary key(box_id,user_id)
);
create index room_treasure_claim_user on public.room_treasure_claims(user_id,claimed_at desc);
alter table public.room_treasure_boxes enable row level security;
alter table public.room_treasure_claims enable row level security;
revoke all on public.room_treasure_boxes,public.room_treasure_claims from public,anon,authenticated;
-- Retry keys stay private even from other authorized room participants.
grant select(id,sender_id,room_id,scope,eligibility,total_coins,quantity,claimed_count,
 remaining_coins,refunded_coins,created_at,expires_at,refunded_at) on public.room_treasure_boxes to authenticated;
grant select on public.room_treasure_claims to authenticated;

-- Security-definer helper prevents policies depending on caller table grants.
create function nimzo_private.treasure_joined(p_room uuid,p_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.room_members m join public.rooms r on r.id=m.room_id
 join public.profiles p on p.id=m.user_id where m.room_id=p_room and m.user_id=p_user
 and r.status='open' and p.status='active'
 and not exists(select 1 from public.room_bans b where b.room_id=p_room and b.user_id=p_user))
$$;
revoke all on function nimzo_private.treasure_joined(uuid,uuid) from public,anon,authenticated;
create function public.can_view_room_treasure(p_room uuid,p_scope text,p_sender uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and status='active')
 and (p_sender=auth.uid() or nimzo_private.treasure_joined(p_room,auth.uid()) or
 (p_scope='world' and not exists(select 1 from public.room_bans where room_id=p_room and user_id=auth.uid())
 and exists(select 1 from public.room_members m where m.user_id=auth.uid() and nimzo_private.treasure_joined(m.room_id,auth.uid()))))
$$;
revoke all on function public.can_view_room_treasure(uuid,text,uuid) from public,anon;
grant execute on function public.can_view_room_treasure(uuid,text,uuid) to authenticated;
create policy treasure_visible on public.room_treasure_boxes for select to authenticated
 using(public.can_view_room_treasure(room_id,scope,sender_id));
create policy treasure_own_claims on public.room_treasure_claims for select to authenticated using(user_id=(select auth.uid()));

create function public.create_room_treasure(p_room uuid,p_scope text,p_total bigint,p_quantity integer,p_eligibility text,p_key text,p_expected_sender uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); b public.room_treasure_boxes; r public.rooms; balance bigint;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if p_expected_sender is distinct from u then raise exception 'TREASURE_ACCOUNT_CHANGED' using errcode='22023';end if;
 if nullif(trim(p_key),'') is null or length(p_key)>200 then raise exception 'TREASURE_INVALID_REQUEST';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('treasure:'||u::text||':'||p_key,0));
 select * into b from public.room_treasure_boxes where sender_id=u and client_key=p_key;
 if found then
  if b.room_id is distinct from p_room or b.scope is distinct from p_scope or b.total_coins is distinct from p_total
   or b.quantity is distinct from p_quantity or b.eligibility is distinct from p_eligibility then raise exception 'TREASURE_PAYLOAD_MISMATCH';end if;
  return jsonb_build_object('id',b.id,'status','replayed');
 end if;
 if p_scope is null or p_scope not in ('room','world') or p_eligibility is null or p_eligibility not in ('all','fans','on_mic')
 or p_quantity is null or p_quantity not in (6,10,20,30) or p_total is null
 or (p_scope='room' and p_total not in (10000,50000,100000,200000))
 or (p_scope='world' and (p_total not in (500000,1000000,5000000,10000000) or p_eligibility='on_mic')) then raise exception 'TREASURE_INVALID_REQUEST';end if;
 if not nimzo_private.treasure_joined(p_room,u) then raise exception 'ROOM_MEMBERSHIP_REQUIRED';end if;
 select * into r from public.rooms where id=p_room for share;
 if not r.perm_gift or not public.room_allows(p_room,u,r.gift_permission) or (p_scope='world' and r.is_private) then raise exception 'ROOM_GIFT_DISABLED';end if;
 select coins into balance from public.wallets where user_id=u for update;
 if not found or balance<p_total then raise exception 'INSUFFICIENT_COINS';end if;
 if (select count(*) from public.room_treasure_boxes where sender_id=u and expires_at>now() and remaining_coins>0 and refunded_at is null)>=20 then raise exception 'TREASURE_ACTIVE_LIMIT';end if;
 insert into public.room_treasure_boxes(sender_id,room_id,scope,eligibility,total_coins,quantity,remaining_coins,client_key)
 values(u,p_room,p_scope,p_eligibility,p_total,p_quantity,p_total,p_key) returning * into b;
 update public.wallets set coins=coins-p_total where user_id=u;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
 values(u,'treasure_fund',-p_total,0,jsonb_build_object('box',b.id,'room',p_room,'quantity',p_quantity),'treasure-fund:'||b.id::text);
 return jsonb_build_object('id',b.id,'status','funded');
end$$;

create function public.claim_room_treasure(p_box uuid,p_room uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); b public.room_treasure_boxes; amount bigint;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 select * into b from public.room_treasure_boxes where id=p_box for update;
 if not found then raise exception 'TREASURE_UNAVAILABLE';end if;
 -- A lost successful response remains recoverable after expiry/room changes.
 select coins into amount from public.room_treasure_claims where box_id=p_box and user_id=u;
 if found then return jsonb_build_object('box_id',p_box,'coins',amount,'status','replayed');end if;
 -- Check wall-clock time AFTER acquiring the box lock. Transaction now()
 -- can predate a long wait and would otherwise allow a late claim.
 if b.expires_at<=clock_timestamp() or b.remaining_coins=0 or b.refunded_at is not null or b.claimed_count>=b.quantity then raise exception 'TREASURE_UNAVAILABLE';end if;
 if b.sender_id=u or not nimzo_private.treasure_joined(p_room,u) or (b.scope='room' and p_room<>b.room_id)
 or exists(select 1 from public.room_bans where room_id=b.room_id and user_id=u)
 or not exists(select 1 from public.rooms where id=b.room_id and status='open')
 or (b.eligibility='fans' and not exists(select 1 from public.follows where follower_id=u and followee_id=b.sender_id))
 or (b.eligibility='on_mic' and not exists(select 1 from public.mic_seats where room_id=b.room_id and user_id=u and not locked)) then raise exception 'TREASURE_NOT_ELIGIBLE';end if;
 amount:=b.total_coins/b.quantity+case when b.claimed_count<(b.total_coins%b.quantity) then 1 else 0 end;
 perform 1 from public.wallets where user_id=u for update;
 if not found then raise exception 'WALLET_NOT_FOUND';end if;
 insert into public.room_treasure_claims(box_id,user_id,coins) values(p_box,u,amount);
 update public.wallets set coins=coins+amount where user_id=u;
 update public.room_treasure_boxes set remaining_coins=remaining_coins-amount,claimed_count=claimed_count+1 where id=p_box;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
 values(u,'treasure_claim',amount,0,jsonb_build_object('box',p_box,'sender',b.sender_id),'treasure-claim:'||p_box::text);
 return jsonb_build_object('box_id',p_box,'coins',amount,'status','claimed');
end$$;

create function public.refund_expired_room_treasures() returns integer
language plpgsql security definer set search_path='' as $$
declare b public.room_treasure_boxes; n integer:=0;
begin
 for b in select * from public.room_treasure_boxes where expires_at<=now() and remaining_coins>0 and refunded_at is null
 order by expires_at,id limit 100 for update skip locked loop
  update public.wallets set coins=coins+b.remaining_coins where user_id=b.sender_id;
  if not found then raise exception 'WALLET_NOT_FOUND';end if;
  insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
  values(b.sender_id,'treasure_refund',b.remaining_coins,0,jsonb_build_object('box',b.id),'treasure-refund:'||b.id::text);
  update public.room_treasure_boxes set refunded_coins=remaining_coins,remaining_coins=0,refunded_at=now() where id=b.id;
  n:=n+1;
 end loop;
 return n;
end$$;

create function public.list_room_treasures(p_room uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); result jsonb;
begin
 if u is null then raise exception 'AUTH_REQUIRED';end if;
 if not nimzo_private.treasure_joined(p_room,u) then raise exception 'ROOM_MEMBERSHIP_REQUIRED';end if;
 select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) into result from (
 select b.id,b.sender_id,p.display_name,b.room_id,b.scope,b.eligibility,b.total_coins,b.quantity,b.claimed_count,
 b.remaining_coins,b.refunded_coins,b.created_at,b.expires_at,b.refunded_at,c.coins as claimed_coins,
 (b.sender_id<>u and c.user_id is null and b.expires_at>now() and b.remaining_coins>0 and b.refunded_at is null
 and b.claimed_count<b.quantity and r.status='open'
 and not exists(select 1 from public.room_bans where room_id=b.room_id and user_id=u)
 and (b.eligibility<>'fans' or exists(select 1 from public.follows where follower_id=u and followee_id=b.sender_id))
 and (b.eligibility<>'on_mic' or exists(select 1 from public.mic_seats where room_id=b.room_id and user_id=u and not locked))) as can_claim
 from public.room_treasure_boxes b join public.profiles p on p.id=b.sender_id join public.rooms r on r.id=b.room_id
 left join public.room_treasure_claims c on c.box_id=b.id and c.user_id=u
 where (b.room_id=p_room or b.scope='world') and public.can_view_room_treasure(b.room_id,b.scope,b.sender_id)
 and (b.expires_at>now() or b.sender_id=u or c.user_id is not null)
 order by b.created_at desc limit 50)x;
 return result;
end$$;
revoke all on function public.create_room_treasure(uuid,text,bigint,integer,text,text,uuid),public.claim_room_treasure(uuid,uuid),public.list_room_treasures(uuid),public.refund_expired_room_treasures() from public,anon,authenticated;
grant execute on function public.create_room_treasure(uuid,text,bigint,integer,text,text,uuid),public.claim_room_treasure(uuid,uuid),public.list_room_treasures(uuid) to authenticated;
grant execute on function public.refund_expired_room_treasures() to service_role;
-- Existing project pg_cron executes this as its scheduling owner, not the app.
select cron.schedule('nimzo-treasure-refunds','*/5 * * * *','select public.refund_expired_room_treasures();');
do $$begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.room_treasure_boxes;
 end if;
end$$;
notify pgrst,'reload schema';
commit;

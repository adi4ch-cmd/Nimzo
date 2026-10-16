-- Animation/progress only. Gift settlement, wallets, rewards and ledger economics
-- are unchanged. Everything below commits/rolls back with the settled gift.
begin;
create table nimzo_private.room_diamond_cycles (
 room_id uuid not null references public.rooms(id) on delete cascade,
 cycle_start timestamptz not null,
 total_coins bigint not null default 0 check (total_coins >= 0),
 primary key(room_id,cycle_start)
);
create table nimzo_private.room_diamond_counted_gifts (
 gift_event_id uuid primary key,
 room_id uuid not null references public.rooms(id) on delete cascade,
 cycle_start timestamptz not null
);
alter table nimzo_private.room_diamond_cycles enable row level security;
alter table nimzo_private.room_diamond_counted_gifts enable row level security;
revoke all on nimzo_private.room_diamond_cycles,nimzo_private.room_diamond_counted_gifts from public,anon,authenticated,service_role;
create table public.room_diamond_blast_events (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.rooms(id) on delete cascade,
 cycle_start timestamptz not null,
 stage smallint not null check(stage between 0 and 5),
 target_coins bigint not null,
 gift_event_id uuid not null,
 created_at timestamptz not null default statement_timestamp(),
 unique(room_id,cycle_start,stage),
 check(target_coins = (array[5000000,10000000,20000000,30000000,50000000,100000000]::bigint[])[stage+1])
);
create index room_diamond_blast_events_room_time_idx on public.room_diamond_blast_events(room_id,created_at);
-- Supports the one-time baseline scan for each room/cycle.
create index if not exists gift_events_diamond_room_cycle_idx on public.gift_events(room_id,created_at) include(total_coins);
alter table public.room_diamond_blast_events enable row level security;
revoke all on public.room_diamond_blast_events from public,anon,authenticated,service_role;
grant select on public.room_diamond_blast_events to authenticated;

create function nimzo_private.room_diamond_cycle_start(p_now timestamptz)
returns timestamptz language sql immutable set search_path = '' as $$
 select (date_trunc('day',p_now at time zone 'UTC' - interval '20 hours') + interval '20 hours') at time zone 'UTC'
$$;

-- Definer lookup avoids depending on client-visible membership policies.
create function nimzo_private.room_diamond_is_member(p_room uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and exists(select 1 from public.room_members m where m.room_id=p_room and m.user_id=auth.uid())
$$;
revoke all on function nimzo_private.room_diamond_is_member(uuid) from public,anon,authenticated,service_role;
grant execute on function nimzo_private.room_diamond_is_member(uuid) to authenticated;
create policy room_diamond_member_read on public.room_diamond_blast_events
 for select to authenticated using(nimzo_private.room_diamond_is_member(room_id));

-- Caller holds the room/cycle advisory transaction lock. Seed once from existing
-- settled events, excluding the statement's inserted rows, without historical blast events.
create function nimzo_private.room_diamond_initialize(p_room uuid,p_cycle timestamptz,p_exclude uuid[] default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not exists(select 1 from nimzo_private.room_diamond_cycles where room_id=p_room and cycle_start=p_cycle) then
  insert into nimzo_private.room_diamond_cycles(room_id,cycle_start,total_coins)
  select p_room,p_cycle,coalesce(sum(greatest(e.total_coins,0)),0)::bigint from public.gift_events e
  where e.room_id=p_room and e.created_at>=p_cycle and e.created_at<p_cycle+interval '24 hours'
   and (p_exclude is null or not (e.id=any(p_exclude)));
 end if;
end $$;

create function nimzo_private.room_diamond_settled()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
 v_cycle timestamptz := nimzo_private.room_diamond_cycle_start(statement_timestamp());
 new public.gift_events%rowtype; v_new_ids uuid[];
 v_before bigint; v_after bigint; v_inserted integer; v_stage integer;
 v_targets constant bigint[] := array[5000000,10000000,20000000,30000000,50000000,100000000]::bigint[];
begin
 select array_agg(id) into v_new_ids from diamond_new_gifts;
 -- Statement transition rows exclude ALL newly inserted gifts from the baseline.
 -- Stable room ordering also prevents cross-room batch deadlocks.
 for new in select * from diamond_new_gifts order by room_id,id loop
 if new.room_id is null or new.total_coins<=0 then continue; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('nimzo:diamond:'||new.room_id::text||':'||extract(epoch from v_cycle)::bigint::text,0));
 perform nimzo_private.room_diamond_initialize(new.room_id,v_cycle,v_new_ids);
 insert into nimzo_private.room_diamond_counted_gifts(gift_event_id,room_id,cycle_start)
 values(new.id,new.room_id,v_cycle) on conflict(gift_event_id) do nothing;
 get diagnostics v_inserted = row_count;
 if v_inserted=0 then continue; end if;
 select total_coins into v_before from nimzo_private.room_diamond_cycles where room_id=new.room_id and cycle_start=v_cycle;
 update nimzo_private.room_diamond_cycles set total_coins=total_coins+new.total_coins
 where room_id=new.room_id and cycle_start=v_cycle returning total_coins into v_after;
 for v_stage in 0..5 loop
  if v_before<v_targets[v_stage+1] and v_after>=v_targets[v_stage+1] then
   insert into public.room_diamond_blast_events(room_id,cycle_start,stage,target_coins,gift_event_id)
   values(new.room_id,v_cycle,v_stage,v_targets[v_stage+1],new.id)
   on conflict(room_id,cycle_start,stage) do nothing;
  end if;
 end loop;
 end loop;
 return null;
end $$;
create trigger room_diamond_settled after insert on public.gift_events
 referencing new table as diamond_new_gifts
 for each statement execute function nimzo_private.room_diamond_settled();

create function public.room_diamond_status(p_room uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_now timestamptz := statement_timestamp();
 v_cycle timestamptz := nimzo_private.room_diamond_cycle_start(v_now);
 v_total bigint; v_completed integer := 0; v_active integer; v_previous bigint;
 v_targets constant bigint[] := array[5000000,10000000,20000000,30000000,50000000,100000000]::bigint[];
 v_progress numeric;
begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not nimzo_private.room_diamond_is_member(p_room) then raise exception 'room membership required' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('nimzo:diamond:'||p_room::text||':'||extract(epoch from v_cycle)::bigint::text,0));
 perform nimzo_private.room_diamond_initialize(p_room,v_cycle);
 select total_coins into v_total from nimzo_private.room_diamond_cycles where room_id=p_room and cycle_start=v_cycle;
 for i in 1..6 loop if v_total>=v_targets[i] then v_completed:=i; end if; end loop;
 v_active:=least(v_completed,5);
 v_previous:=case when v_active=0 then 0 else v_targets[v_active] end;
 v_progress:=least(1::numeric,greatest(0::numeric,(v_total-v_previous)::numeric/(v_targets[v_active+1]-v_previous)));
 return jsonb_build_object('server_now',v_now,'cycle_start',v_cycle,'reset_at',v_cycle+interval '24 hours',
 'total_coins',v_total,'thresholds',to_jsonb(v_targets),'completed_stages',v_completed,'active_stage',v_active,'progress',v_progress);
end $$;
revoke all on function public.room_diamond_status(uuid) from public,anon,authenticated,service_role;
grant execute on function public.room_diamond_status(uuid) to authenticated;
revoke all on function nimzo_private.room_diamond_cycle_start(timestamptz),nimzo_private.room_diamond_initialize(uuid,timestamptz,uuid[]),nimzo_private.room_diamond_settled() from public,anon,authenticated,service_role;
-- Realtime is optional in clones and added only once when publication exists.
do $$ begin
 if exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_catalog.pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='room_diamond_blast_events')
 and not exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime' and puballtables) then
  alter publication supabase_realtime add table public.room_diamond_blast_events;
 end if;
end $$;
commit;

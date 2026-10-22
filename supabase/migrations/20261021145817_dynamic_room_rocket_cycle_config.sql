-- REVIEW/STAGING PROPOSAL ONLY; no live application or financial mutations.
-- Requires the existing six-Haza Rocket trigger and verified-media publication
-- proposal. New decoder code still requires a new application release.
begin;

create or replace function nimzo_internal.valid_room_rocket_stages(
 p_thresholds bigint[],p_artwork smallint[],p_labels text[]
) returns boolean language plpgsql immutable set search_path='' as $$
declare v_previous bigint:=0;
begin
 if p_thresholds is null or array_ndims(p_thresholds)<>1
  or array_lower(p_thresholds,1)<>1 or cardinality(p_thresholds) not between 1 and 6
  or p_artwork is null or array_ndims(p_artwork)<>1 or array_lower(p_artwork,1)<>1
  or cardinality(p_artwork)<>cardinality(p_thresholds)
  or p_labels is null or array_ndims(p_labels)<>1 or array_lower(p_labels,1)<>1
  or cardinality(p_labels)<>cardinality(p_thresholds) then return false; end if;
 for i in 1..cardinality(p_thresholds) loop
  if p_thresholds[i] is null or p_thresholds[i]<=v_previous or p_thresholds[i]>9007199254740991
   or p_artwork[i] is null or p_artwork[i] not between 1 and 6
   or p_labels[i] is null or length(btrim(p_labels[i])) not between 1 and 48 then return false; end if;
  v_previous:=p_thresholds[i];
 end loop;
 return true;
end;
$$;
create or replace function nimzo_internal.valid_room_rocket_media(p_media jsonb,p_count integer)
returns boolean language plpgsql immutable set search_path='' as $$
declare v_media jsonb;
begin
 if p_media is null or jsonb_typeof(p_media)<>'array'
   or jsonb_array_length(p_media)<>p_count then return false; end if;
 for v_media in select value from jsonb_array_elements(p_media) loop
  if v_media='null'::jsonb then continue; end if;
  if jsonb_typeof(v_media)<>'object'
    or v_media->>'codec' is distinct from 'vap'
    or v_media->>'mime_type' is distinct from 'video/mp4'
    or v_media->>'sound_mode' is null
    or v_media->>'sound_mode' not in ('embedded','synthesized','muted')
    or jsonb_typeof(v_media->'byte_size') is distinct from 'number'
    or (v_media->>'byte_size') !~ '^[0-9]{1,8}$'
    or not nimzo_internal.valid_media_publication(
      v_media->>'url',v_media->>'sha256',(v_media->>'byte_size')::bigint,
      v_media->>'mime_type',v_media->>'codec',v_media->>'rights_reference',
      (v_media->>'verified_at')::timestamptz,(v_media->>'device_verified_at')::timestamptz
    ) then return false; end if;
 end loop;
 return true;
exception when others then return false;
end;
$$;
revoke all on function nimzo_internal.valid_room_rocket_stages(bigint[],smallint[],text[]),
 nimzo_internal.valid_room_rocket_media(jsonb,integer) from public,anon,authenticated;

create table public.room_rocket_configs (
 version bigint primary key check(version>=1),
 title text not null check(length(btrim(title)) between 1 and 80),
 subtitle text not null check(length(subtitle)<=180),
 thresholds bigint[] not null,
 artwork_stages smallint[] not null,
 stage_labels text[] not null,
 fly_media jsonb not null,
 reward_media jsonb not null,
 active boolean not null default false,
 published_at timestamptz,
 created_at timestamptz not null default now(),
 check(nimzo_internal.valid_room_rocket_stages(thresholds,artwork_stages,stage_labels)),
 check(jsonb_typeof(fly_media)='array' and jsonb_array_length(fly_media)=cardinality(thresholds)),
 check(jsonb_typeof(reward_media)='array' and jsonb_array_length(reward_media)=cardinality(thresholds)),
 check(pg_column_size(fly_media)+pg_column_size(reward_media)<=32768),
 check(not active or published_at is not null)
);
create unique index room_rocket_single_active_config on public.room_rocket_configs(active) where active;
alter table public.room_rocket_configs enable row level security;
revoke all on public.room_rocket_configs from public,anon,authenticated;
grant select on public.room_rocket_configs to authenticated;
create policy room_rocket_published_config_read on public.room_rocket_configs
 for select to authenticated using(published_at is not null);

-- Published snapshots remain immutable/readable after deactivation. Drafts may
-- be edited; publication requires actual verified bytes/rights/device evidence.
create or replace function nimzo_internal.guard_room_rocket_config()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Rocket configuration versions cannot be deleted' using errcode='22023'; end if;
 if tg_op='UPDATE' then
  if new.version<>old.version then raise exception 'Rocket version is immutable' using errcode='22023'; end if;
  if (old.published_at is not null or exists(select 1 from nimzo_private.room_diamond_cycles cy where cy.config_version=old.version))
   and (to_jsonb(new)-'active') is distinct from (to_jsonb(old)-'active') then
   raise exception 'Published Rocket configuration is immutable' using errcode='22023';
  end if;
  if old.published_at is null and new.published_at is not null then
   raise exception 'Rocket publication timestamp is server assigned' using errcode='22023';
  end if;
 elsif new.published_at is not null then
  raise exception 'Rocket publication timestamp is server assigned' using errcode='22023';
 end if;
 if new.active then
  if not nimzo_internal.valid_room_rocket_media(new.fly_media,cardinality(new.thresholds))
    or not nimzo_internal.valid_room_rocket_media(new.reward_media,cardinality(new.thresholds)) then
   raise exception 'Rocket effects need verified immutable VAP media and device/rights evidence' using errcode='22023';
  end if;
  if new.published_at is null then
   if exists(select 1 from public.room_rocket_configs c where c.published_at is not null and c.version>=new.version) then
    raise exception 'New Rocket publication version must increase' using errcode='22023';
   end if;
   new.published_at:=statement_timestamp();
  end if;
 end if;
 return new;
end;
$$;
revoke all on function nimzo_internal.guard_room_rocket_config() from public,anon,authenticated;
create trigger room_rocket_config_guard before insert or update or delete on public.room_rocket_configs
 for each row execute function nimzo_internal.guard_room_rocket_config();
create trigger nimzo_revision_rocket_configs after insert or update or delete on public.room_rocket_configs
 for each statement execute function nimzo_internal.bump_content_revision('settings');
insert into public.room_rocket_configs(version,title,subtitle,thresholds,artwork_stages,stage_labels,fly_media,reward_media,active)
 values(1,'ROOM ROCKET','Gift together to launch six rocket levels',
 array[5000000,10000000,20000000,30000000,50000000,100000000]::bigint[],
 array[1,2,3,4,5,6]::smallint[],array['Rocket 1','Rocket 2','Rocket 3','Rocket 4','Rocket 5','Rocket 6'],
 '[null,null,null,null,null,null]','[null,null,null,null,null,null]',true);

-- First assign every EXISTING cycle to the original set. The original
-- initialize function and historical milestone amounts stay untouched.
alter table nimzo_private.room_diamond_cycles add column config_version bigint not null default 1
 references public.room_rocket_configs(version) on delete restrict;

-- ALTER TABLE above holds the cycle table's exclusive lock until COMMIT.
-- Seed directly using the original initializer's baseline rule, without taking
-- room advisory locks AFTER that table lock (which could deadlock with a live
-- status/settlement transaction already holding its room advisory lock).
-- Committed existing cycles are preserved; in-flight gifts remain invisible
-- here and their original trigger counts them after this migration commits.
insert into nimzo_private.room_diamond_cycles(room_id,cycle_start,total_coins,config_version)
 select r.id,c.cycle_start,coalesce(sum(greatest(e.total_coins,0)),0)::bigint,1
 from public.rooms r
 cross join (select nimzo_private.room_diamond_cycle_start(statement_timestamp()) as cycle_start) c
 left join public.gift_events e on e.room_id=r.id and e.created_at>=c.cycle_start
   and e.created_at<c.cycle_start+interval '24 hours'
 group by r.id,c.cycle_start
 on conflict(room_id,cycle_start) do nothing;

create or replace function nimzo_private.current_room_rocket_config_version()
returns bigint language plpgsql security definer set search_path='' as $$
declare v_version bigint;
begin
 select c.version into v_version from public.room_rocket_configs c
  where c.active and c.published_at is not null for share;
 -- Deactivation never disables gifting or an existing cycle. A future cycle
 -- with no active publication uses the original complete six-level fallback.
 return coalesce(v_version,1);
end;
$$;
revoke all on function nimzo_private.current_room_rocket_config_version() from public,anon,authenticated,service_role;
alter table nimzo_private.room_diamond_cycles alter column config_version
 set default nimzo_private.current_room_rocket_config_version();

create or replace function nimzo_internal.guard_room_rocket_cycle_pin()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.config_version is distinct from old.config_version then
  raise exception 'Rocket cycle configuration is pinned' using errcode='22023';
 end if;
 return new;
end;
$$;
revoke all on function nimzo_internal.guard_room_rocket_cycle_pin() from public,anon,authenticated;
create trigger room_rocket_cycle_pin_guard before update of config_version on nimzo_private.room_diamond_cycles
 for each row execute function nimzo_internal.guard_room_rocket_cycle_pin();

alter table public.room_diamond_blast_events
 add column config_version bigint not null default 1 references public.room_rocket_configs(version) on delete restrict,
 add column artwork_stage smallint check(artwork_stage between 1 and 6);
-- Keep any older extended-stage history intact; only the six supported levels
-- have a compiled-art mapping. New events are validated against their snapshot.
update public.room_diamond_blast_events set artwork_stage=stage+1 where stage between 0 and 5;
do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.room_diamond_blast_events'::regclass
   and conname='rocket_target_v2_check' and contype='c'
   and position('target_coins' in pg_get_constraintdef(oid))>0
   and position('ARRAY[' in pg_get_constraintdef(oid))>0) then
  raise exception 'Unrecognized legacy Rocket target check; review required';
 end if;
 alter table public.room_diamond_blast_events drop constraint rocket_target_v2_check;
 alter table public.room_diamond_blast_events add constraint rocket_target_v3_bounds
   check(target_coins between 1 and 9007199254740991);
end;
$$;

-- Surgical patch: retain actual gift accounting, transition rows, stable room
-- ordering, advisory lock, counted-event PK, and milestone UNIQUE constraint.
do $$
declare v_definition text; v_old text; v_new text;
begin
 v_definition:=pg_get_functiondef('nimzo_private.room_diamond_settled()'::regprocedure);
 for v_old,v_new in select * from (values
  ('v_targets constant bigint[] := nimzo_private.room_rocket_targets_v2()::bigint[];',
   'v_targets bigint[]; v_config_version bigint; v_artwork_stages smallint[];'),
  ('perform nimzo_private.room_diamond_initialize(new.room_id,v_cycle,v_new_ids);',
   'perform nimzo_private.room_diamond_initialize(new.room_id,v_cycle,v_new_ids);
 select c.thresholds,c.version,c.artwork_stages into v_targets,v_config_version,v_artwork_stages
 from nimzo_private.room_diamond_cycles cy join public.room_rocket_configs c on c.version=cy.config_version
 where cy.room_id=new.room_id and cy.cycle_start=v_cycle;'),
  ('for v_stage in 0..5 loop','for v_stage in 0..(cardinality(v_targets)-1) loop'),
  ('room_diamond_blast_events(room_id,cycle_start,stage,target_coins,gift_event_id)',
   'room_diamond_blast_events(room_id,cycle_start,stage,target_coins,gift_event_id,config_version,artwork_stage)'),
  ('values(new.room_id,v_cycle,v_stage,v_targets[v_stage+1],new.id)',
   'values(new.room_id,v_cycle,v_stage,v_targets[v_stage+1],new.id,v_config_version,v_artwork_stages[v_stage+1])')
 ) as patches(old_part,new_part) loop
  if (length(v_definition)-length(replace(v_definition,v_old,'')))/length(v_old)<>1 then
   raise exception 'Unrecognized Rocket trigger fragment: %',v_old;
  end if;
  v_definition:=replace(v_definition,v_old,v_new);
 end loop;
 execute v_definition;
end;
$$;

-- Validate NEW events without changing or reinterpreting historical events.
create or replace function nimzo_internal.guard_room_rocket_event_config()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_config public.room_rocket_configs%rowtype;
begin
 select c.* into v_config from nimzo_private.room_diamond_cycles cy
  join public.room_rocket_configs c on c.version=cy.config_version
  where cy.room_id=new.room_id and cy.cycle_start=new.cycle_start;
 if not found or new.config_version<>v_config.version
  or new.stage not between 0 and cardinality(v_config.thresholds)-1
  or new.target_coins is distinct from v_config.thresholds[new.stage+1]
  or new.artwork_stage is distinct from v_config.artwork_stages[new.stage+1] then
  raise exception 'Rocket milestone does not match pinned cycle configuration' using errcode='22023';
 end if;
 return new;
end;
$$;
revoke all on function nimzo_internal.guard_room_rocket_event_config() from public,anon,authenticated;
create trigger room_rocket_event_config_guard before insert on public.room_diamond_blast_events
 for each row execute function nimzo_internal.guard_room_rocket_event_config();

create or replace function nimzo_private.room_rocket_status_v3(p_room uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_now timestamptz:=statement_timestamp();
 v_cycle timestamptz:=nimzo_private.room_diamond_cycle_start(v_now);
 v_config public.room_rocket_configs%rowtype;
 v_total bigint; v_completed integer:=0; v_active integer; v_previous bigint; v_progress numeric;
begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 if not nimzo_private.room_diamond_is_member(p_room) then raise exception 'room membership required' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('nimzo:diamond:'||p_room::text||':'||extract(epoch from v_cycle)::bigint::text,0));
 perform nimzo_private.room_diamond_initialize(p_room,v_cycle);
 select cy.total_coins into v_total from nimzo_private.room_diamond_cycles cy
  where cy.room_id=p_room and cy.cycle_start=v_cycle;
 select c.* into v_config from nimzo_private.room_diamond_cycles cy
  join public.room_rocket_configs c on c.version=cy.config_version
  where cy.room_id=p_room and cy.cycle_start=v_cycle;
 for i in 1..cardinality(v_config.thresholds) loop
  if v_total>=v_config.thresholds[i] then v_completed:=i; end if;
 end loop;
 v_active:=least(v_completed,cardinality(v_config.thresholds)-1);
 v_previous:=case when v_active=0 then 0 else v_config.thresholds[v_active] end;
 v_progress:=least(1::numeric,greatest(0::numeric,(v_total-v_previous)::numeric/(v_config.thresholds[v_active+1]-v_previous)));
 return jsonb_build_object('server_now',v_now,'cycle_start',v_cycle,'reset_at',v_cycle+interval '24 hours',
  'total_coins',v_total,'thresholds',to_jsonb(v_config.thresholds),'completed_stages',v_completed,
  'active_stage',v_active,'progress',v_progress,'config_version',v_config.version,
  'artwork_stages',to_jsonb(v_config.artwork_stages),'stage_labels',to_jsonb(v_config.stage_labels),
  'title',v_config.title,'subtitle',v_config.subtitle,'fly_media',v_config.fly_media,'reward_media',v_config.reward_media);
end;
$$;
create or replace function public.room_rocket_status_v3(p_room uuid)
returns jsonb language sql security invoker set search_path='' as $$
 select nimzo_private.room_rocket_status_v3(p_room)
$$;
revoke all on function nimzo_private.room_rocket_status_v3(uuid),public.room_rocket_status_v3(uuid) from public,anon,authenticated,service_role;
grant execute on function nimzo_private.room_rocket_status_v3(uuid),public.room_rocket_status_v3(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

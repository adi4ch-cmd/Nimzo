-- PROPOSED ONLY: do not apply until owner/backend/device acceptance.
-- Purely additive presentation; no wallet, price, reward or entitlement writes.
begin;
create table public.nimzo_membership_presentations (
 kind text not null check (kind in ('vip','svip')),
 tier integer not null check (tier between 1 and 10),
 title text not null check (length(title) between 1 and 80),
 hero jsonb, badge jsonb, entrance jsonb,
 benefit_keys text[] not null default '{}'::text[],
 active boolean not null default false,
 approved boolean not null default false,
 version bigint not null default 1 check (version > 0),
 source_record text not null check (length(source_record) between 1 and 2048),
 rights_record text not null check (length(rights_record) between 1 and 2048),
 device_proof_record text,
 updated_at timestamptz not null default now(),
 primary key (kind,tier),
 check (benefit_keys <@ array['badge','room_entry','daily_reward','weekly_reward']::text[]),
 check (not ('daily_reward'=any(benefit_keys)) or kind='vip'),
 check (not ('weekly_reward'=any(benefit_keys)) or kind='svip'),
 check (not active or approved),
 check (not approved or (hero is not null and badge is not null
   and nullif(trim(device_proof_record),'') is not null))
);
alter table public.nimzo_membership_presentations enable row level security;
revoke all on public.nimzo_membership_presentations from public,anon,authenticated;
-- Provenance/audit strings stay owner-only. Client receives presentation only.
grant select(kind,tier,title,hero,badge,entrance,benefit_keys,active,approved,version)
 on public.nimzo_membership_presentations to authenticated;
grant all on public.nimzo_membership_presentations to service_role;
create policy nimzo_membership_published_read on public.nimzo_membership_presentations
 for select to authenticated using(active and approved);

create function nimzo_internal.validate_membership_presentation()
returns trigger language plpgsql set search_path='' as $$
declare media jsonb; role_name text; max_bytes bigint; fmt text; digest text;
begin
 if tg_op='UPDATE' then new.version:=old.version+1; end if;
 new.updated_at:=now();
 foreach role_name in array array['hero','badge','entrance'] loop
  media:=to_jsonb(new)->role_name;
  if media is null or media='null'::jsonb then continue; end if;
  max_bytes:=case when role_name='entrance' then 16777216 else 4194304 end;
  fmt:=media->>'format'; digest:=media->>'sha256';
  if jsonb_typeof(media)<>'object'
   or coalesce(media->>'url','') !~ '^https://[^[:space:]@]+$'
   or length(media->>'url')>2048
   or coalesce(digest,'') !~ '^[a-f0-9]{64}$'
   or position(digest in split_part(media->>'url','?',1))=0
   or coalesce(media->>'bytes','') !~ '^[1-9][0-9]{0,8}$'
   or (media->>'bytes')::bigint>max_bytes
   or fmt is null
   or (role_name='entrance' and fmt not in ('svga','vap'))
   or (role_name<>'entrance' and fmt not in ('png','webp','jpeg')) then
    raise exception 'Invalid membership % descriptor',role_name using errcode='23514';
  end if;
 end loop;
 return new;
end $$;
revoke all on function nimzo_internal.validate_membership_presentation() from public,anon,authenticated;
create trigger nimzo_membership_validate before insert or update on public.nimzo_membership_presentations
 for each row execute function nimzo_internal.validate_membership_presentation();
create trigger nimzo_membership_revision after insert or update or delete on public.nimzo_membership_presentations
 for each statement execute function nimzo_internal.bump_content_revision('settings');
-- Reuse the existing settings revision channel; never weaken its CHECK/RLS.
-- Catalog monetary/reward rows remain the existing server-authoritative source.
create trigger nimzo_vip_catalog_revision after insert or update or delete on public.normal_vip_catalog
 for each statement execute function nimzo_internal.bump_content_revision('settings');
create trigger nimzo_svip_threshold_revision after insert or update or delete on public.svip_thresholds
 for each statement execute function nimzo_internal.bump_content_revision('settings');
create trigger nimzo_vip_reward_revision after insert or update or delete on public.vip_daily_rewards
 for each statement execute function nimzo_internal.bump_content_revision('settings');
create trigger nimzo_svip_reward_revision after insert or update or delete on public.svip_friday_rewards
 for each statement execute function nimzo_internal.bump_content_revision('settings');
-- Deliberately seed NOTHING: new artwork is staged outside the app until proved.
-- Checked-price extension reuses the reviewed atomic legacy settlement and
-- ledger replay semantics. Lock order matches all calls to this new endpoint.
create function public.nimzo_purchase_vip_checked(p_tier integer,p_key text,p_expected_coins bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_existing jsonb; v_price bigint;
begin
 if v_user is null then raise exception 'Sign in required'; end if;
 if p_tier is null or p_tier not between 1 and 10 or p_key is null
  or length(trim(p_key))<8 or length(p_key)>128 then
  raise exception 'Invalid membership purchase'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('normal_vip:'||v_user::text||':'||p_key,0));
 select ref into v_existing from public.ledger where user_id=v_user
  and kind='vip_purchase' and idempotency_key='vip:'||p_key;
 if found then
  if (v_existing->>'tier')::integer is distinct from p_tier then
   raise exception 'Purchase idempotency payload mismatch'; end if;
  -- Recovery uses immutable original receipt terms, never today's price.
  if (v_existing->>'price')::bigint is distinct from p_expected_coins then
   raise exception 'Purchase idempotency price mismatch' using errcode='22023'; end if;
  return public.purchase_normal_vip(p_tier,p_key);
 end if;
 select coin_price into v_price from public.normal_vip_catalog where tier=p_tier for share;
 if v_price is null or p_expected_coins is distinct from v_price then
  raise exception 'VIP price changed; refresh and confirm again' using errcode='22023'; end if;
 return public.purchase_normal_vip(p_tier,p_key);
end $$;
revoke all on function public.nimzo_purchase_vip_checked(integer,text,bigint) from public,anon,authenticated;
grant execute on function public.nimzo_purchase_vip_checked(integer,text,bigint) to authenticated;
commit;

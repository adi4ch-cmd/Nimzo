-- Tracked baseline for the already-deployed Supabase family_and_moment_media
-- change dated 2026-10-18 03:54. Do NOT re-run manually on production.
-- This file supplies the previously absent schema to future fresh deployments.
-- Additive/idempotent; no family, wallet, Moment or user data is deleted.

create table if not exists public.nimzo_families (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 40),
  description text not null default '' check (char_length(description) <= 500),
  created_at timestamptz not null default now()
);
create table if not exists public.nimzo_family_members (
  family_id uuid not null references public.nimzo_families(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);
create index if not exists nimzo_family_members_user
on public.nimzo_family_members(user_id);

alter table public.nimzo_families enable row level security;
alter table public.nimzo_family_members enable row level security;
revoke all on public.nimzo_families,public.nimzo_family_members from anon, authenticated;
grant select,delete on public.nimzo_families,public.nimzo_family_members to authenticated;
drop policy if exists family_directory on public.nimzo_families;
create policy family_directory on public.nimzo_families for select
 to authenticated using (true);
drop policy if exists family_dissolve on public.nimzo_families;
create policy family_dissolve on public.nimzo_families for delete
 to authenticated using (owner_id = (select auth.uid()));
drop policy if exists family_edit on public.nimzo_families;
create policy family_edit on public.nimzo_families for update
 to authenticated using (owner_id = (select auth.uid()))
 with check (owner_id = (select auth.uid()));
drop policy if exists family_members_read on public.nimzo_family_members;
create policy family_members_read on public.nimzo_family_members for select
 to authenticated using (true);
drop policy if exists family_join on public.nimzo_family_members;
create policy family_join on public.nimzo_family_members for insert
 to authenticated with check (
   user_id = (select auth.uid()) and exists (
     select 1 from public.nimzo_families f
     where f.id = family_id and f.owner_id <> (select auth.uid())
   )
 );
drop policy if exists family_leave on public.nimzo_family_members;
create policy family_leave on public.nimzo_family_members for delete
 to authenticated using (user_id = (select auth.uid()));

-- The existing private function is authoritative for creation cost and ledger.
-- Public facade is INVOKER, while the private function uses the authenticated UID.
create or replace function nimzo_private.create_family(
  p_name text,p_description text,p_key text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
 uid uuid:=auth.uid();
 balance bigint;
 entry public.ledger%rowtype;
 family uuid;
 title text:=btrim(p_name);
 description text:=btrim(coalesce(p_description,''));
begin
 if uid is null or not exists(
   select 1 from public.profiles where id=uid and status='active'
 ) then
  raise exception 'Active account required' using errcode='42501';
 end if;
 if title is null or char_length(title) not between 2 and 40
    or char_length(description)>500
    or p_key is null or p_key !~ '^[a-zA-Z0-9_-]{8,100}$' then
  raise exception 'Invalid family request' using errcode='22023';
 end if;
 select coins into balance from public.wallets where user_id=uid for update;
 if not found then raise exception 'Wallet unavailable' using errcode='23514'; end if;
 select * into entry from public.ledger where user_id=uid
   and kind='family_creation' and idempotency_key='family-create:'||p_key;
 if found then
  if entry.ref->>'name' is distinct from title or
     entry.ref->>'description' is distinct from description then
    raise exception 'Request key conflict' using errcode='22023';
  end if;
  family=(entry.ref->>'family_id')::uuid;
  if not exists(select 1 from public.nimzo_families
                where id=family and owner_id=uid) then
    raise exception 'Family no longer exists' using errcode='23514';
  end if;
  return jsonb_build_object('created',true,'family_id',family,
    'charged_coins',0,'already_processed',true);
 end if;
 if exists(select 1 from public.nimzo_families where owner_id=uid) then
  raise exception 'You already own a family' using errcode='23505';
 end if;
 if balance<1000000 then
  raise exception 'Family creation requires 1,000,000 coins'
   using errcode='23514';
 end if;
 insert into public.nimzo_families(owner_id,name,description)
 values(uid,title,description) returning id into family;
 update public.wallets set coins=coins-1000000 where user_id=uid;
 insert into public.ledger(user_id,kind,coin_delta,diamond_delta,ref,idempotency_key)
 values(uid,'family_creation',-1000000,0,
  jsonb_build_object('family_id',family,'name',title,'description',description),
  'family-create:'||p_key);
 return jsonb_build_object('created',true,'family_id',family,
   'charged_coins',1000000,'already_processed',false);
end;
$$;
revoke all on function nimzo_private.create_family(text,text,text) from public,anon;
grant execute on function nimzo_private.create_family(text,text,text) to authenticated;

create or replace function public.create_family(
  p_name text,p_description text,p_key text)
returns jsonb language sql set search_path = ''
as $$
 select nimzo_private.create_family(p_name,p_description,p_key)
$$;
revoke all on function public.create_family(text,text,text) from public,anon;
grant execute on function public.create_family(text,text,text) to authenticated;

-- Preserve image_path for all legacy consumers; the array is authoritative
-- when editing multi-image Moments.
alter table public.moments
 add column if not exists image_paths text[] not null default '{}'::text[];
update public.moments set image_paths=array[image_path]
where image_path is not null and cardinality(image_paths)=0;
create or replace function public.nimzo_moment_media_guard()
returns trigger language plpgsql set search_path = ''
as $$
declare path text; changed boolean;
begin
 if TG_OP='INSERT' then
  if cardinality(new.image_paths)=0 and new.image_path is not null then
    new.image_paths=array[new.image_path];
  end if;
  changed=true;
 else
  changed=new.image_paths is distinct from old.image_paths or
          new.image_path is distinct from old.image_path;
  if new.image_paths is not distinct from old.image_paths and
     new.image_path is distinct from old.image_path then
   new.image_paths=case when new.image_path is null
     then '{}'::text[] else array[new.image_path] end;
  end if;
 end if;
 if changed then
  foreach path in array new.image_paths loop
   if path not like new.author_id::text||'/%' or
      path like '%..%' or char_length(path)>512 then
    raise exception 'Moment images must belong to the author'
       using errcode='23514';
   end if;
  end loop;
 end if;
 new.image_path=new.image_paths[1];
 return new;
end;
$$;
revoke all on function public.nimzo_moment_media_guard() from public,anon,authenticated;
drop trigger if exists nimzo_moment_media_guard on public.moments;
create trigger nimzo_moment_media_guard
  before insert or update on public.moments
  for each row execute function public.nimzo_moment_media_guard();

create or replace function public.moments_feed_v2()
returns jsonb language sql stable set search_path = ''
as $$
 select coalesce(jsonb_agg(to_jsonb(feed) order by feed.created_at desc),
   '[]'::jsonb)
 from (
   select m.id,m.author_id,m.body,m.image_path,m.image_paths,m.created_at,
   (select count(*) from public.moment_likes l where l.moment_id=m.id) as like_count,
   (select count(*) from public.moment_comments c where c.moment_id=m.id) as comment_count,
   exists(select 1 from public.moment_likes l
      where l.moment_id=m.id and l.user_id=auth.uid()) as liked
   from public.moments m order by m.created_at desc limit 100
 ) feed
$$;
revoke all on function public.moments_feed_v2() from public,anon;
grant execute on function public.moments_feed_v2() to authenticated;

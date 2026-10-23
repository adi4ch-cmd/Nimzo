-- Additive presentation metadata only; no prices, wallets or entitlements.
-- Keep hero's top-level descriptor static for previously released clients.
begin;
alter table public.nimzo_membership_presentations add column card jsonb;
grant select(card) on public.nimzo_membership_presentations to authenticated;

create or replace function nimzo_internal.validate_membership_presentation()
returns trigger language plpgsql set search_path='' as $$
declare media jsonb; role_name text; max_bytes bigint; fmt text; digest text;
begin
 if tg_op='UPDATE' then new.version:=old.version+1; end if;
 new.updated_at:=now();
 foreach role_name in array array['hero','badge','entrance','card','hero_animation'] loop
  if role_name='hero_animation' then
   if new.hero is null or not (new.hero ? 'animation') then continue; end if;
   media:=new.hero->'animation';
  else
   media:=to_jsonb(new)->role_name;
   if media is null or media='null'::jsonb then continue; end if;
  end if;
  max_bytes:=case when role_name='entrance' then 16777216 else 4194304 end;
  fmt:=media->>'format'; digest:=media->>'sha256';
  if jsonb_typeof(media) is distinct from 'object'
   or coalesce(media->>'url','') !~ '^https://[^[:space:]@]+$'
   or length(media->>'url')>2048
   or coalesce(digest,'') !~ '^[a-f0-9]{64}$'
   or position(digest in split_part(media->>'url','?',1))=0
   or coalesce(media->>'bytes','') !~ '^[1-9][0-9]{0,8}$'
   or (media->>'bytes')::bigint>max_bytes
   or fmt is null
   or (role_name='entrance' and fmt not in ('svga','vap'))
   or (role_name='hero_animation' and fmt<>'svga')
   or (role_name not in ('entrance','hero_animation') and fmt not in ('png','webp','jpeg')) then
    raise exception 'Invalid membership % descriptor',role_name using errcode='23514';
  end if;
 end loop;
 return new;
end $$;
revoke all on function nimzo_internal.validate_membership_presentation() from public,anon,authenticated;
commit;

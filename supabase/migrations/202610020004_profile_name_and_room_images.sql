begin;
alter table public.rooms add column if not exists avatar_path text;

create or replace function public.update_room_settings(p_room uuid, p_settings jsonb)
returns void
language plpgsql
security definer
set search_path to public, extensions
as $function$
declare k text;
begin
  if not exists(select 1 from rooms where id=p_room and owner_id=auth.uid()) and not is_admin() then
    raise exception 'only the owner can change settings';
  end if;
  for k in select jsonb_object_keys(p_settings) loop
    if k not in ('name','country','theme','avatar_path','is_private','rules','mic_permission','chat_permission','guest_permission','gift_permission','music_permission','game_permission','visitor_permission','perm_mic','perm_chat','perm_guest','perm_gift','perm_music','perm_game','perm_visitor') then
      raise exception 'field not editable: %',k;
    end if;
  end loop;
  if p_settings ? 'theme' and (p_settings->>'theme') not in ('nimzo_white','sage','ocean','lavender','rose','midnight','premium_black','luxury') then
    raise exception 'bad theme';
  end if;
  update rooms set
    name=coalesce(p_settings->>'name',name),
    country=coalesce(p_settings->>'country',country),
    theme=coalesce(p_settings->>'theme',theme),
    avatar_path=coalesce(p_settings->>'avatar_path',avatar_path),
    is_private=coalesce((p_settings->>'is_private')::boolean,is_private),
    rules=coalesce(p_settings->>'rules',rules),
    mic_permission=coalesce(p_settings->>'mic_permission',mic_permission),
    chat_permission=coalesce(p_settings->>'chat_permission',chat_permission),
    guest_permission=coalesce(p_settings->>'guest_permission',guest_permission),
    gift_permission=coalesce(p_settings->>'gift_permission',gift_permission),
    music_permission=coalesce(p_settings->>'music_permission',music_permission),
    game_permission=coalesce(p_settings->>'game_permission',game_permission),
    visitor_permission=coalesce(p_settings->>'visitor_permission',visitor_permission),
    perm_mic=coalesce((p_settings->>'perm_mic')::boolean,perm_mic),
    perm_chat=coalesce((p_settings->>'perm_chat')::boolean,perm_chat),
    perm_guest=coalesce((p_settings->>'perm_guest')::boolean,perm_guest),
    perm_gift=coalesce((p_settings->>'perm_gift')::boolean,perm_gift),
    perm_music=coalesce((p_settings->>'perm_music')::boolean,perm_music),
    perm_game=coalesce((p_settings->>'perm_game')::boolean,perm_game),
    perm_visitor=coalesce((p_settings->>'perm_visitor')::boolean,perm_visitor)
  where id=p_room;
end
$function$;

insert into storage.buckets (id,name,public)
values ('room-images','room-images',true)
on conflict (id) do update set public=true;

drop policy if exists room_image_upload on storage.objects;
create policy room_image_upload on storage.objects for insert to authenticated
with check (
  bucket_id='room-images'
  and exists (select 1 from public.rooms r where r.id=(storage.foldername(name))[1]::uuid and r.owner_id=auth.uid())
);

drop policy if exists room_image_update on storage.objects;
create policy room_image_update on storage.objects for update to authenticated
using (
  bucket_id='room-images'
  and exists (select 1 from public.rooms r where r.id=(storage.foldername(name))[1]::uuid and r.owner_id=auth.uid())
)
with check (
  bucket_id='room-images'
  and exists (select 1 from public.rooms r where r.id=(storage.foldername(name))[1]::uuid and r.owner_id=auth.uid())
);
commit;

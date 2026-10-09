-- Keep existing owner authorization, editable fields and password hashing.
-- Both existing RPCs execute inside this single request/transaction, so a
-- failed photo update cannot leave the remaining settings partially committed.
create or replace function public.save_room_settings(
  p_room uuid, p_name text, p_theme text, p_private boolean, p_password text,
  p_mic boolean, p_chat boolean, p_guest boolean, p_gift boolean,
  p_music boolean, p_game boolean, p_visitor boolean, p_avatar_path text
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  perform public.update_room_settings(
    p_room, p_name, p_theme, p_private, p_password,
    p_mic, p_chat, p_guest, p_gift, p_music, p_game, p_visitor
  );
  if p_avatar_path is not null then
    perform public.update_room_settings(
      p_room, pg_catalog.jsonb_build_object('avatar_path', p_avatar_path)
    );
  end if;
end;
$$;
revoke all on function public.save_room_settings(uuid,text,text,boolean,text,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text) from public, anon;
grant execute on function public.save_room_settings(uuid,text,text,boolean,text,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text) to authenticated;

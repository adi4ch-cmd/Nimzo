-- Distinct temporary kick and permanent ban; legacy kick_member remains unchanged.
create function public.get_room_moderation(p_room uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='28000'; end if;
 return public.can_moderate(p_room,auth.uid());
end $$;
create function public.moderate_room_member(p_room uuid,p_user uuid,p_ban boolean) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target_svip integer;
begin
 if actor is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_room is null or p_user is null or p_ban is null then raise exception 'invalid moderation action' using errcode='22023'; end if;
 -- Lock the room before authorization to serialize against room ownership changes.
 perform 1 from public.rooms where id=p_room for update;
 if not found or not public.can_moderate(p_room,actor) then raise exception 'not allowed' using errcode='42501'; end if;
 if exists(select 1 from public.rooms where id=p_room and owner_id=p_user) then raise exception 'cannot kick owner' using errcode='42501'; end if;
 select svip_level into target_svip from public.profiles where id=p_user for update;
 if not found then raise exception 'member unavailable' using errcode='22023'; end if;
 if target_svip>=5 and not public.is_admin() then raise exception 'target is protected' using errcode='42501'; end if;
 update public.mic_seats set user_id=null where room_id=p_room and user_id=p_user;
 delete from public.room_members where room_id=p_room and user_id=p_user;
 if p_ban then insert into public.room_bans(room_id,user_id) values(p_room,p_user) on conflict do nothing; end if;
end $$;
revoke all on function public.get_room_moderation(uuid),public.moderate_room_member(uuid,uuid,boolean) from public,anon;
grant execute on function public.get_room_moderation(uuid),public.moderate_room_member(uuid,uuid,boolean) to authenticated;

create or replace function public.create_room(p_name text, p_country text, p_password text default null)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare rid uuid; v_nimzo bigint;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists(select 1 from public.rooms where owner_id=auth.uid() and status='open') then raise exception 'you already have an open room'; end if;
  if nullif(trim(coalesce(p_name,'')),'') is null then raise exception 'room name is required'; end if;
  if length(trim(p_name)) > 40 then raise exception 'room name is too long'; end if;
  select nimzo_id into v_nimzo from public.profiles where id=auth.uid() and status='active';
  if v_nimzo is null then raise exception 'profile unavailable'; end if;
  if exists(select 1 from public.rooms where room_no=v_nimzo) then raise exception 'room number already exists for this user'; end if;
  insert into public.rooms(room_no,owner_id,name,country,is_private,password_hash)
  values (v_nimzo,auth.uid(),trim(p_name),nullif(trim(coalesce(p_country,'')),''),coalesce(p_password,'')<>'',
    case when coalesce(p_password,'')<>'' then crypt(p_password,gen_salt('bf')) end)
  returning id into rid;
  insert into public.mic_seats(room_id,seat_no) select rid,g from generate_series(1,10) g on conflict (room_id,seat_no) do nothing;
  insert into public.room_members(room_id,user_id,role) values(rid,auth.uid(),'member') on conflict do nothing;
  return rid;
end
$function$;

drop view if exists public.rooms_ranked;
create view public.rooms_ranked as
select r.*, coalesce(mc.member_count,0)::bigint as member_count,
       row_number() over(order by coalesce(mc.member_count,0) desc, r.last_active desc nulls last, r.created_at desc)::bigint as rank
from public.rooms r
left join (select room_id,count(*)::bigint as member_count from public.room_members group by room_id) mc on mc.room_id=r.id
where r.status='open';

grant select on public.rooms_ranked to anon, authenticated;

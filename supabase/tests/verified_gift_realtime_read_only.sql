-- Read-only assertions suitable for both a disposable clone and production.
do $$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
   and schemaname='public' and tablename='gift_animation_events') then
   raise exception 'Verified gift animation events are absent from Realtime';
 end if;
 if exists(select 1 from pg_class where oid in ('public.gift_animation_events'::regclass,'public.gift_animation_media'::regclass)
   and not relrowsecurity) then raise exception 'Gift animation RLS missing'; end if;
 if not has_table_privilege('authenticated','public.gift_animation_events','select')
   or not has_table_privilege('authenticated','public.gift_animation_media','select') then
   raise exception 'Authenticated approved gift reads unavailable';
 end if;
 if has_table_privilege('authenticated','public.gift_animation_events','insert,update,delete,truncate,references,trigger')
   or has_table_privilege('authenticated','public.gift_animation_media','insert,update,delete,truncate,references,trigger')
   or has_table_privilege('anon','public.gift_animation_events','select,insert,update,delete,truncate,references,trigger')
   or has_table_privilege('anon','public.gift_animation_media','select,insert,update,delete,truncate,references,trigger') then
   raise exception 'Untrusted clients retain gift event/media privileges';
 end if;
end $$;

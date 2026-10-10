-- Read-only schema metadata; no application rows, credentials or auth users.
-- Save the schema_snapshot JSON value and pass it to verify_backend_contracts.py.
select jsonb_build_object(
 'tables',(select jsonb_agg(jsonb_build_object('name',c.relname,'rls',c.relrowsecurity,
   'columns',(select jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'identity',a.attidentity,'default',pg_get_expr(d.adbin,d.adrelid)) order by a.attnum)
     from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped),
   'constraints',(select jsonb_agg(jsonb_build_object('name',co.conname,'definition',pg_get_constraintdef(co.oid))) from pg_constraint co where co.conrelid=c.oid)))
   from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),
 'indexes',(select jsonb_agg(pg_get_indexdef(i.indexrelid)) from pg_index i join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not exists(select 1 from pg_constraint co where co.conindid=i.indexrelid)),
 'functions',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'identity',pg_get_function_identity_arguments(p.oid),'definition',pg_get_functiondef(p.oid),
   'anon',has_function_privilege('anon',p.oid,'EXECUTE'),'authenticated',has_function_privilege('authenticated',p.oid,'EXECUTE'),'service_role',has_function_privilege('service_role',p.oid,'EXECUTE')))
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','nimzo_private') and p.prokind='f'),
 'policies',(select jsonb_agg(jsonb_build_object('table',tablename,'name',policyname,'cmd',cmd,'roles',roles,'qual',qual,'check',with_check)) from pg_policies where schemaname='public'),
 'column_grants',(select jsonb_agg(jsonb_build_object('table',table_name,'column',column_name,'role',grantee,'privilege',privilege_type)) from information_schema.column_privileges where table_schema='public' and grantee in ('anon','authenticated','service_role')),
 'triggers',(select jsonb_agg(pg_get_triggerdef(t.oid)) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and n.nspname in ('auth','public')),
 'views',(select jsonb_agg(jsonb_build_object('name',c.relname,'definition',pg_get_viewdef(c.oid),'options',c.reloptions)) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v')
) as schema_snapshot;

alter table auth.users disable trigger user;
insert into auth.users(id,email) select ('00000000-0000-4000-8000-00000000010'||n)::uuid,'fixture'||n||'@example.invalid' from generate_series(1,3)n;
insert into public.profiles(id) select id from auth.users;
insert into public.wallets(user_id,coins) values ('00000000-0000-4000-8000-000000000101',3000000),('00000000-0000-4000-8000-000000000102',100),('00000000-0000-4000-8000-000000000103',3000000);
-- Local auth shim only; production auth.jwt is supplied by Supabase.
create or replace function auth.jwt() returns jsonb language sql stable as $$
 select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)
$$;

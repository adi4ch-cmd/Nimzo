-- Activation only after owner Firebase configuration and secure Vault entries exist.
-- Run as database owner. The worker bearer remains encrypted in Vault.
begin;
create extension if not exists pg_net with schema extensions;
do $$begin
 if not exists(select 1 from vault.secrets where name='nimzo_push_worker_service_key') then
 raise exception 'Create the push service-key Vault secret first';end if;
end$$;
select cron.schedule('nimzo-fcm-delivery','* * * * *',$job$
 select net.http_post(
  url:='https://kvqvlpozqokwarovwmwv.supabase.co/functions/v1/push-notifications',
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='nimzo_push_worker_service_key')),
  body:='{}'::jsonb,timeout_milliseconds:=100000
 );
$job$);

commit;

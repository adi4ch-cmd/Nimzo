-- Narrow scheduler credential only; never copy/export the service-role key.
create extension if not exists pg_net with schema extensions;
create table nimzo_private.push_dispatch_receipts (
 nonce uuid primary key,
 accepted_at timestamptz not null default clock_timestamp()
);
alter table nimzo_private.push_dispatch_receipts enable row level security;
revoke all on nimzo_private.push_dispatch_receipts from public,anon,authenticated;
grant all on nimzo_private.push_dispatch_receipts to service_role;
create policy push_dispatch_backend on nimzo_private.push_dispatch_receipts for all to service_role using(true) with check(true);
do $$begin
 if not exists(select 1 from vault.secrets where name='nimzo_push_dispatch_hmac') then
 perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'nimzo_push_dispatch_hmac','Scoped one-time NIMZO push dispatcher signatures');
 end if;
end$$;
create function nimzo_private.authorize_push_dispatch(p_time text,p_nonce uuid,p_signature text) returns boolean
language plpgsql security definer set search_path='' as $$
declare secret text; expected text;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Not authorized' using errcode='42501';end if;
 if p_time is null or p_time !~ '^[0-9]{10}$' or p_nonce is null or p_signature is null or p_signature !~ '^[a-f0-9]{64}$' then return false;end if;
 if abs(extract(epoch from clock_timestamp())-p_time::bigint)>90 then return false;end if;
 select decrypted_secret into secret from vault.decrypted_secrets where name='nimzo_push_dispatch_hmac' limit 1;
 if secret is null then return false;end if;
 expected:=encode(extensions.hmac(convert_to('nimzo-push-v1:'||p_time||':'||p_nonce::text,'UTF8'),decode(secret,'hex'),'sha256'),'hex');
 if expected<>p_signature then return false;end if;
 delete from nimzo_private.push_dispatch_receipts where accepted_at<clock_timestamp()-interval '1 day';
 insert into nimzo_private.push_dispatch_receipts(nonce) values(p_nonce) on conflict do nothing;
 return found;
end$$;
revoke all on function nimzo_private.authorize_push_dispatch(text,uuid,text) from public,anon,authenticated;
grant execute on function nimzo_private.authorize_push_dispatch(text,uuid,text) to service_role;
create function public.authorize_push_dispatch(p_time text,p_nonce uuid,p_signature text) returns boolean
language sql security invoker set search_path='' as $$select nimzo_private.authorize_push_dispatch(p_time,p_nonce,p_signature)$$;
revoke all on function public.authorize_push_dispatch(text,uuid,text) from public,anon,authenticated;
grant execute on function public.authorize_push_dispatch(text,uuid,text) to service_role;
create function nimzo_private.dispatch_push_tick(p_force boolean default false) returns bigint
language plpgsql security definer set search_path='' as $$
declare key text; gateway text; stamp text; nonce uuid:=gen_random_uuid(); signature text; request_id bigint;
begin
 if not p_force and not exists(select 1 from nimzo_private.push_outbox where status='pending' and available_at<=now() and (locked_until is null or locked_until<now())) then return null;end if;
 select decrypted_secret into key from vault.decrypted_secrets where name='nimzo_push_dispatch_hmac' limit 1;
 select decrypted_secret into gateway from vault.decrypted_secrets where name='nimzo_push_gateway_anon' limit 1;
 if key is null or gateway is null then raise exception 'Push dispatch authentication is not configured';end if;
 stamp:=floor(extract(epoch from clock_timestamp()))::bigint::text;
 signature:=encode(extensions.hmac(convert_to('nimzo-push-v1:'||stamp||':'||nonce::text,'UTF8'),decode(key,'hex'),'sha256'),'hex');
 select net.http_post(url:='https://kvqvlpozqokwarovwmwv.supabase.co/functions/v1/push-notifications',
 headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||gateway,
 'X-Nimzo-Dispatch-Time',stamp,'X-Nimzo-Dispatch-Nonce',nonce::text,'X-Nimzo-Dispatch-Signature',signature),body:='{}'::jsonb,timeout_milliseconds:=100000) into request_id;
 return request_id;
end$$;
revoke all on function nimzo_private.dispatch_push_tick(boolean) from public,anon,authenticated,service_role;
-- Cron activation is a separate verified operator step after a successful probe.
notify pgrst,'reload schema';

-- Preserve the existing encrypted credential and service-only RPC contract.
create function nimzo_private.get_push_firebase_service_account() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Not authorized' using errcode='42501';end if;
 select decrypted_secret::jsonb into result from vault.decrypted_secrets where name='nimzo_fcm_service_account' limit 1;
 if result is null then raise exception 'Push credentials not configured';end if;
 return result;
end$$;
revoke all on function nimzo_private.get_push_firebase_service_account() from public,anon,authenticated;
grant execute on function nimzo_private.get_push_firebase_service_account() to service_role;
create or replace function public.get_push_firebase_service_account() returns jsonb
language sql security invoker set search_path='' as $$select nimzo_private.get_push_firebase_service_account()$$;
revoke all on function public.get_push_firebase_service_account() from public,anon,authenticated;
grant execute on function public.get_push_firebase_service_account() to service_role;
notify pgrst,'reload schema';

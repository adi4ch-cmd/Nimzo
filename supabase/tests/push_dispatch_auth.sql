begin;
-- Fake platform services ONLY in the disposable local clone.
set local role service_role;
do $$declare stamp text:=floor(extract(epoch from clock_timestamp()))::bigint::text;
 nonce uuid:=gen_random_uuid(); sig text;
begin
 sig:=encode(extensions.hmac(convert_to('nimzo-push-v1:'||stamp||':'||nonce::text,'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex');
 if not public.authorize_push_dispatch(stamp,nonce,sig) then raise exception 'Valid signature rejected';end if;
 if public.authorize_push_dispatch(stamp,nonce,sig) then raise exception 'Replayed dispatch accepted';end if;
 if public.authorize_push_dispatch(stamp,gen_random_uuid(),repeat('0',64)) then raise exception 'Forged dispatch accepted';end if;
 if public.authorize_push_dispatch('1',gen_random_uuid(),sig) then raise exception 'Expired dispatch accepted';end if;
end$$;
reset role;
set local role authenticated;
do $$begin
 begin perform public.authorize_push_dispatch('1',gen_random_uuid(),repeat('0',64));raise exception 'User can authorize worker';exception when insufficient_privilege then null;end;
 begin perform public.get_push_firebase_service_account();raise exception 'User can read Firebase key';exception when insufficient_privilege then null;end;
end$$;
reset role;
rollback;

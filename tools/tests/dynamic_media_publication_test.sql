-- Run ONLY against a fresh disposable PostgreSQL database, never live.
\set ON_ERROR_STOP on
create schema nimzo_internal;
create table public.gifts(id uuid primary key, coin_price bigint, active boolean, requires_approved_media boolean default false);
create table public.gift_animation_media(gift_id uuid primary key, video_url text, approved boolean, media_kind text);
create table public.nimzo_cosmetic_catalog(id text primary key, coin_price bigint, active boolean);
create table public.nimzo_cosmetic_media(item_id text primary key, asset_url text, approved boolean, media_kind text);
create table public.ledger(kind text,coin_delta bigint,ref jsonb);
create table public.gift_events(gift_id uuid);
create table public.wallet_fixture(coins bigint);
insert into public.wallet_fixture values(100);
-- Preserve an approved legacy row lacking metadata; migration must not rewrite it.
insert into public.gifts values('00000000-0000-0000-0000-000000000001',10,true,false);
insert into public.gift_animation_media values('00000000-0000-0000-0000-000000000001','https://cdn.example/old.mp4',true,'mp4');
\ir ../../supabase/migrations/20261021120000_dynamic_verified_media_publications.sql
create trigger nimzo_guard_paid_room_gift_media before insert on public.gift_events
for each row execute function nimzo_internal.reject_unplayable_settled_gift();

begin;
do $$
declare h text:=repeat('a',64); u text:='https://cdn.example/'||repeat('a',64)||'.png';
        g uuid:='00000000-0000-0000-0000-000000000002';
begin
 if not exists(select 1 from public.gift_animation_media where approved and sha256 is null) then
   raise exception 'legacy rows changed'; end if;
 if nimzo_internal.valid_media_publication(u,h,12,'text/html','image','rights',now(),now()) then
   raise exception 'MIME allowed'; end if;
 if nimzo_internal.valid_media_publication('https://cdn.example/changed.png',h,12,'image/png','image','rights',now(),now()) then
   raise exception 'mutable URL allowed'; end if;
 if nimzo_internal.valid_media_publication(u,h,33554433,'image/png','image','rights',now(),now()) then
   raise exception 'oversize allowed'; end if;
 if nimzo_internal.valid_media_publication(u,h,12,'image/png','image','rights',now(),null) then
   raise exception 'missing device proof allowed'; end if;
 insert into public.gifts(id,coin_price,active) values(g,10,false);
 if not (select requires_approved_media from public.gifts where id=g) then raise exception 'default bypass'; end if;
 insert into public.nimzo_cosmetic_catalog values('test-frame',10,true);
 insert into public.nimzo_cosmetic_media(item_id,asset_url,approved,media_kind) values('test-frame',u,false,'image');
 begin
   update public.nimzo_cosmetic_media set approved=true where item_id='test-frame';
   raise exception 'unverified approval accepted';
 exception when sqlstate '22023' then null;
 end;
 -- Emulate existing atomic purchase: any downstream media guard failure must
 -- roll back the preceding wallet mutation in the SAME transaction/subtransaction.
 begin
   update public.wallet_fixture set coins=coins-10;
   insert into public.ledger values('store_purchase',-10,'{"item_id":"test-frame"}');
   raise exception 'unverified media charge accepted';
 exception when sqlstate '22023' then null;
 end;
 if (select coins from public.wallet_fixture)<>100 then raise exception 'wallet debit survived failure'; end if;
 update public.nimzo_cosmetic_media set sha256=h,byte_size=12,mime_type='image/png',rights_reference='owner record',verified_at=now(),device_verified_at=now(),approved=true;
 insert into public.ledger values('store_purchase',-10,'{"item_id":"test-frame"}');
 update public.nimzo_cosmetic_catalog set coin_price=11;
 begin
   insert into public.ledger values('store_purchase',-10,'{"item_id":"test-frame"}');
   raise exception 'stale price accepted';
 exception when sqlstate '22023' then null;
 end;
 update public.nimzo_cosmetic_catalog set coin_price=10,active=false;
 begin
   insert into public.ledger values('store_purchase',-10,'{"item_id":"test-frame"}');
   raise exception 'deactivated purchase accepted';
 exception when sqlstate '22023' then null;
 end;
 begin
   insert into public.gift_events values(g);
   raise exception 'unverified gift settlement accepted';
 exception when sqlstate '22023' then null;
 end;
 insert into public.gift_animation_media(gift_id,video_url,approved,media_kind,sha256,byte_size,mime_type,rights_reference,verified_at,device_verified_at)
 values(g,'https://cdn.example/'||h||'.mp4',true,'mp4',h,12,'video/mp4','owner record',now(),now());
 update public.gifts set active=true where id=g;
 insert into public.gift_events values(g);
 update public.gift_animation_media set approved=false where gift_id=g;
 begin
   insert into public.gift_events values(g);
   raise exception 'deapproved gift settlement accepted';
 exception when sqlstate '22023' then null;
 end;
 raise notice 'PASS: metadata, old row preservation, staged approval, wallet rollback, price/deactivation and gift publication guards';
end $$;
rollback;

-- Nimzo production catalog seed (safe/idempotent).
-- Source of truth remains Supabase production; this migration keeps schema/data setup reproducible from GitHub.
insert into public.recharge_packages (product_id, coins, usd_cents, active) values
('nimzo_coins_1',500000,100,true),
('nimzo_coins_5',2500000,500,true),
('nimzo_coins_10',5000000,1000,true),
('nimzo_coins_20',10000000,2000,true),
('nimzo_coins_50',25000000,5000,true),
('nimzo_coins_100',50000000,10000,true)
on conflict (product_id) do update set coins=excluded.coins, usd_cents=excluded.usd_cents, active=true;

insert into public.gifts (name,category,coin_price,asset_path,min_vip,min_svip,active) values
('Rose','classic',500,null,0,0,true),
('Heart','classic',1000,null,0,0,true),
('Kiss','classic',2500,null,0,0,true),
('Coffee','classic',5000,null,0,0,true),
('Crown','premium',10000,null,0,0,true),
('Diamond','premium',25000,null,0,0,true),
('Rocket','premium',50000,null,0,0,true),
('Sports Car','premium',100000,null,0,0,true),
('Luxury Yacht','premium',250000,null,1,0,true),
('Private Jet','premium',500000,null,2,0,true),
('Golden Palace','vip',1000000,null,3,0,true),
('Royal Dragon','svip',2500000,null,0,1,true),
('Phoenix','svip',5000000,null,0,3,true)
on conflict do nothing;

insert into public.economy_settings(setting_key,numeric_value,active)
values ('coins_per_usd',500000,true),('diamond_effect_percent',30,true)
on conflict (setting_key) do update set numeric_value=excluded.numeric_value,active=true;

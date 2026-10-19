-- Stage approved animal gifts until private upload and next-client QA succeed.
-- Do not charge for unavailable media in the old APK.
insert into public.gifts(id,name,category,coin_price,asset_path,min_vip,min_svip,active)
values
('629b0f33-55b5-5084-8488-865869e9ab39','Ice Fire Phoenix','premium',1000000,'private-gift-thumbnail:629b0f33-55b5-5084-8488-865869e9ab39',0,0,false),
('2f869219-7cdd-531b-9715-c5d8c9cd864d','Holy Tiger','premium',1000000,'private-gift-thumbnail:2f869219-7cdd-531b-9715-c5d8c9cd864d',0,0,false)
on conflict(id) do update set name=excluded.name,category=excluded.category,
coin_price=excluded.coin_price,asset_path=excluded.asset_path,min_vip=excluded.min_vip,min_svip=excluded.min_svip;

-- Apply only after all eight private objects are verified and gateway deployed.
update public.gifts set active=true
where id in ('53f6278f-1770-5be9-ae07-329c34f36c47',
'5e07ac17-491a-4a26-a48b-e6701445705f',
'629b0f33-55b5-5084-8488-865869e9ab39',
'2f869219-7cdd-531b-9715-c5d8c9cd864d');

-- Original bundled media products. Decorative badges grant no account privileges.
-- Existing inventory, pricing and equipment are preserved.
begin;
insert into public.nimzo_cosmetic_catalog (id,category,name,variant,coin_price,active) values
('nimzo-media-frame-gold-circle','Avatar Frame','Gold Circle',0,0,true),
('nimzo-media-frame-gold-cp','Avatar Frame','Gold Halo',1,0,true),
('nimzo-media-frame-family','Avatar Frame','Family Frame',2,0,true),
('nimzo-media-frame-cp','Avatar Frame','Cp Frame',3,0,true),
('nimzo-media-frame-room','Avatar Frame','Room Frame',4,0,true),
('nimzo-media-portrait-1','Avatar Frame','Portrait 1',5,0,true),
('nimzo-media-portrait-2','Avatar Frame','Portrait 2',6,0,true),
('nimzo-media-portrait-3','Avatar Frame','Portrait 3',0,0,true),
('nimzo-media-badge-agency-leader','Royal Badge','Agency Leader',1,0,true),
('nimzo-media-badge-exclusive-identity','Royal Badge','Exclusive Identity',2,0,true),
('nimzo-media-badge-golden-royalty','Royal Badge','Golden Royalty',3,0,true),
('nimzo-media-badge-grand-millionaire','Royal Badge','Grand Millionaire',4,0,true),
('nimzo-media-badge-imperial-crown','Royal Badge','Imperial Crown',5,0,true),
('nimzo-media-badge-loyal-heart','Royal Badge','Loyal Heart',6,0,true),
('nimzo-media-badge-millionaire','Royal Badge','Millionaire',0,0,true),
('nimzo-media-badge-room-guardian','Royal Badge','Room Guardian',1,0,true),
('nimzo-media-badge-ruby-legend','Royal Badge','Ruby Legend',2,0,true),
('nimzo-media-badge-supreme-champion','Royal Badge','Supreme Champion',3,0,true),
('nimzo-media-badge-ultimate-supporter','Royal Badge','Ultimate Supporter',4,0,true),
('nimzo-media-theme-gold','Party Theme','Golden Room',5,0,true),
('nimzo-media-theme-citadel','Party Theme','Citadel Room',6,0,true),
('nimzo-media-chat-white','Chat Bubble','White Bubble',0,0,true),
('nimzo-media-profile-blue','Profile Card','Blue Gold Card',1,0,true),
('nimzo-media-id-gold','ID Frame','Gold Nameplate',2,0,true),
('nimzo-media-live-gold','Live Frame','Golden Room Banner',3,0,true),
('nimzo-media-mic-voiceroom_mic_wave_default','Mic Wave','Pulse',4,0,true),
('nimzo-media-mic-cp_mic_seat_anim','Mic Wave','Heart Pulse',5,0,true),
('nimzo-media-entrance-1','Rides','Flight 1',6,0,true),
('nimzo-media-entrance-2','Rides','Flight 2',0,0,true),
('nimzo-media-entrance-3','Rides','Flight 3',1,0,true),
('nimzo-media-entrance-4','Rides','Flight 4',2,0,true),
('nimzo-media-entrance-5','Rides','Flight 5',3,0,true)
on conflict (id) do nothing;
commit;

import '../../core/services/approved_media_bytes.dart';

enum CosmeticMediaKind { image, svga, vap }

class CosmeticMedia {
  const CosmeticMedia(
    this.id,
    this.category,
    this.name,
    this.asset,
    this.kind, {
    this.thumbnail,
    this.publication,
    this.thumbnailPublication,
  });
  final String id, category, name, asset;
  final CosmeticMediaKind kind;
  final String? thumbnail;
  final ApprovedMediaPublication? publication;
  final ApprovedMediaPublication? thumbnailPublication;
}

// IDs and bundled paths are pinned together; catalog data cannot inject a URL.
const premiumCosmetics = <String, CosmeticMedia>{
  'nimzo-media-frame-gold-circle': CosmeticMedia(
    'nimzo-media-frame-gold-circle',
    'Avatar Frame',
    'Gold Circle',
    'assets/premium_store/willchill/ic_avatar_frame_gold_circle.png',
    CosmeticMediaKind.image,
  ),
  'nimzo-media-frame-gold-cp': CosmeticMedia(
    'nimzo-media-frame-gold-cp',
    'Avatar Frame',
    'Gold Halo',
    'assets/premium_store/willchill/icon_user_info_cp_avatar_frame.png',
    CosmeticMediaKind.image,
  ),
  'nimzo-media-frame-family': CosmeticMedia(
    'nimzo-media-frame-family',
    'Avatar Frame',
    'Family Frame',
    'assets/premium_store/danglive/frame-family.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-frame-cp': CosmeticMedia(
    'nimzo-media-frame-cp',
    'Avatar Frame',
    'Cp Frame',
    'assets/premium_store/danglive/frame-cp.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-frame-room': CosmeticMedia(
    'nimzo-media-frame-room',
    'Avatar Frame',
    'Room Frame',
    'assets/premium_store/danglive/frame-room.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-portrait-1': CosmeticMedia(
    'nimzo-media-portrait-1',
    'Avatar Frame',
    'Portrait 1',
    'assets/premium_store/danglive/top1.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-portrait-2': CosmeticMedia(
    'nimzo-media-portrait-2',
    'Avatar Frame',
    'Portrait 2',
    'assets/premium_store/danglive/top2.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-portrait-3': CosmeticMedia(
    'nimzo-media-portrait-3',
    'Avatar Frame',
    'Portrait 3',
    'assets/premium_store/danglive/top3.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-agency-leader': CosmeticMedia(
    'nimzo-media-badge-agency-leader',
    'Royal Badge',
    'Agency Leader',
    'assets/premium_store/danglive/agency-leader.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-exclusive-identity': CosmeticMedia(
    'nimzo-media-badge-exclusive-identity',
    'Royal Badge',
    'Exclusive Identity',
    'assets/premium_store/danglive/exclusive-identity.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-golden-royalty': CosmeticMedia(
    'nimzo-media-badge-golden-royalty',
    'Royal Badge',
    'Golden Royalty',
    'assets/premium_store/danglive/golden-royalty.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-grand-millionaire': CosmeticMedia(
    'nimzo-media-badge-grand-millionaire',
    'Royal Badge',
    'Grand Millionaire',
    'assets/premium_store/danglive/grand-millionaire.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-imperial-crown': CosmeticMedia(
    'nimzo-media-badge-imperial-crown',
    'Royal Badge',
    'Imperial Crown',
    'assets/premium_store/danglive/imperial-crown.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-loyal-heart': CosmeticMedia(
    'nimzo-media-badge-loyal-heart',
    'Royal Badge',
    'Loyal Heart',
    'assets/premium_store/danglive/loyal-heart.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-millionaire': CosmeticMedia(
    'nimzo-media-badge-millionaire',
    'Royal Badge',
    'Millionaire',
    'assets/premium_store/danglive/millionaire.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-room-guardian': CosmeticMedia(
    'nimzo-media-badge-room-guardian',
    'Royal Badge',
    'Room Guardian',
    'assets/premium_store/danglive/room-guardian.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-ruby-legend': CosmeticMedia(
    'nimzo-media-badge-ruby-legend',
    'Royal Badge',
    'Ruby Legend',
    'assets/premium_store/danglive/ruby-legend.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-supreme-champion': CosmeticMedia(
    'nimzo-media-badge-supreme-champion',
    'Royal Badge',
    'Supreme Champion',
    'assets/premium_store/danglive/supreme-champion.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-badge-ultimate-supporter': CosmeticMedia(
    'nimzo-media-badge-ultimate-supporter',
    'Royal Badge',
    'Ultimate Supporter',
    'assets/premium_store/danglive/ultimate-supporter.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-theme-gold': CosmeticMedia(
    'nimzo-media-theme-gold',
    'Party Theme',
    'Golden Room',
    'assets/premium_store/danglive/chatroom-bg.png',
    CosmeticMediaKind.image,
  ),
  'nimzo-media-theme-citadel': CosmeticMedia(
    'nimzo-media-theme-citadel',
    'Party Theme',
    'Citadel Room',
    'assets/premium_store/danglive/erbil-bg.png',
    CosmeticMediaKind.image,
  ),
  'nimzo-media-chat-white': CosmeticMedia(
    'nimzo-media-chat-white',
    'Chat Bubble',
    'White Bubble',
    'assets/premium_store/willchill/bg_copy_bubble2.png',
    CosmeticMediaKind.image,
  ),
  'nimzo-media-profile-blue': CosmeticMedia(
    'nimzo-media-profile-blue',
    'Profile Card',
    'Blue Gold Card',
    'assets/premium_store/willchill/chat_send_id_card_bg.png',
    CosmeticMediaKind.image,
  ),
  'nimzo-media-id-gold': CosmeticMedia(
    'nimzo-media-id-gold',
    'ID Frame',
    'Gold Nameplate',
    'assets/premium_store/danglive/profile-id-frame.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-live-gold': CosmeticMedia(
    'nimzo-media-live-gold',
    'Live Frame',
    'Golden Room Banner',
    'assets/premium_store/danglive/cp-nest-frame-new.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-mic-voiceroom_mic_wave_default': CosmeticMedia(
    'nimzo-media-mic-voiceroom_mic_wave_default',
    'Mic Wave',
    'Pulse',
    'assets/premium_store/willchill/voiceroom_mic_wave_default.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-mic-cp_mic_seat_anim': CosmeticMedia(
    'nimzo-media-mic-cp_mic_seat_anim',
    'Mic Wave',
    'Heart Pulse',
    'assets/premium_store/willchill/cp_mic_seat_anim.svga',
    CosmeticMediaKind.svga,
  ),
  'nimzo-media-entrance-1': CosmeticMedia(
    'nimzo-media-entrance-1',
    'Rides',
    'Flight 1',
    'assets/premium_store/willchill/voiceroom_act_lv1_anim.mp4',
    CosmeticMediaKind.vap,
    thumbnail: 'assets/premium_store/willchill/voiceroom_rocket1.png',
  ),
  'nimzo-media-entrance-2': CosmeticMedia(
    'nimzo-media-entrance-2',
    'Rides',
    'Flight 2',
    'assets/premium_store/willchill/voiceroom_act_lv2_anim.mp4',
    CosmeticMediaKind.vap,
    thumbnail: 'assets/premium_store/willchill/voiceroom_rocket2.png',
  ),
  'nimzo-media-entrance-3': CosmeticMedia(
    'nimzo-media-entrance-3',
    'Rides',
    'Flight 3',
    'assets/premium_store/willchill/voiceroom_act_lv3_anim.mp4',
    CosmeticMediaKind.vap,
    thumbnail: 'assets/premium_store/willchill/voiceroom_rocket3.png',
  ),
  'nimzo-media-entrance-4': CosmeticMedia(
    'nimzo-media-entrance-4',
    'Rides',
    'Flight 4',
    'assets/premium_store/willchill/voiceroom_act_lv4_anim.mp4',
    CosmeticMediaKind.vap,
    thumbnail: 'assets/premium_store/willchill/voiceroom_rocket4.png',
  ),
  'nimzo-media-entrance-5': CosmeticMedia(
    'nimzo-media-entrance-5',
    'Rides',
    'Flight 5',
    'assets/premium_store/willchill/voiceroom_act_lv5_anim.mp4',
    CosmeticMediaKind.vap,
    thumbnail: 'assets/premium_store/willchill/voiceroom_rocket5.png',
  ),
};

/// Existing bundled visual assets for each membership tier.
/// These are PREVIEWS only. They never grant/modify membership entitlements.
/// Missing assets are deliberately null rather than fabricated with an icon.
class MembershipPackArtwork {
  const MembershipPackArtwork(this.title, this.path,
      {this.otherSide, this.isTierSpecific = true});
  final String title;
  final String? path;
  final String? otherSide;
  final bool isTierSpecific;

  bool get available => path != null;
}

class MembershipPackInventory {
  static const slots = <String>[
    'Tier background',
    'Avatar frame',
    'ID nameplate',
    'Entry banner',
    'Chat bubble',
    'Mic effect',
    'Profile decoration',
    'Room background',
  ];

  /// Always returns the same eight named slots, even for future tiers.
  /// The selected tier is based on the server catalog, never a fixed UI cap.
  static List<MembershipPackArtwork> forTier(String kind, int tier) {
    if (kind != 'vip' && kind != 'svip') {
      throw ArgumentError.value(kind, 'kind', 'Expected vip or svip');
    }
    if (tier <= 0) {
      throw RangeError.value(tier, 'tier', 'Tier must be positive');
    }
    final vip = kind == 'vip';
    final base = 'assets/willchill_premium/$kind/';
    String? asset(String name, bool present) =>
        present ? '$base$name' : null;
    final hasVipFull = vip && tier <= 5;
    final hasVipArtwork = vip && tier <= 7;
    final hasSvipArtwork = !vip && tier <= 8;
    final vipSuffix = tier == 1 ? '' : '_v$tier';

    return <MembershipPackArtwork>[
      MembershipPackArtwork('Tier background',
          asset(vip ? 'bg_vip${tier}_top_bg_res.webp'
                    : 'fixed_top_svip${tier}_bg.webp',
              hasVipArtwork || hasSvipArtwork)),
      MembershipPackArtwork('Avatar frame',
          asset('icon_vip${tier}_2.png', hasVipFull)),
      MembershipPackArtwork(
        'ID nameplate',
        asset(vip
              ? 'voiceroom_icon_vip_id_left$vipSuffix.png'
              : 'voiceroom_icon_svip_id_left.webp',
              hasVipArtwork || hasSvipArtwork),
        otherSide: asset(vip
              ? 'voiceroom_icon_vip_id_right$vipSuffix.png'
              : 'voiceroom_icon_svip_id_right.webp',
              hasVipArtwork || hasSvipArtwork),
        isTierSpecific: vip,
      ),
      MembershipPackArtwork('Entry banner',
          asset('icon_vip${tier}_3.png', hasVipFull)),
      MembershipPackArtwork('Chat bubble',
          asset('icon_vip${tier}_4.png', hasVipFull)),
      MembershipPackArtwork('Mic effect',
          asset('icon_vip${tier}_5.png', hasVipFull)),
      MembershipPackArtwork('Profile decoration',
          asset('icon_vip${tier}_6.${tier == 1 ? 'webp' : 'png'}',
              hasVipFull)),
      const MembershipPackArtwork('Room background', null),
    ];
  }
}

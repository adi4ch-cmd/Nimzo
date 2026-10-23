/// Bundled illustrations pooled into NIMZO membership packs.
///
/// Assets may originate from *different* VIP/SVIP tiers, as requested.
/// A source tier is artwork provenance, NOT the user's paid/earned tier.
/// The visible pack tag is always the authenticated target kind and tier.
/// This inventory identifies files and safe usage candidates, not successful
/// device playback or permission to claim a borrowed image is newly created.
class MembershipPackArtwork {
  const MembershipPackArtwork(
    this.title,
    this.path, {
    required this.source,
    this.otherSide,
    this.isTierSpecific = false,
  });

  final String title;
  final String? path;
  final String? otherSide;
  final String source;
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

  static int _pick(int tier, int count, int offset) =>
      ((tier - 1 + offset) % count) + 1;

  /// Eight real image candidates for each VIP/SVIP level. The same artwork
  /// can be assigned to a different level or product, with an explicit source
  /// label. Runtime access continues to come from the verified membership RPC.
  static List<MembershipPackArtwork> forTier(String kind, int tier) {
    if (kind != 'vip' && kind != 'svip') {
      throw ArgumentError.value(kind, 'kind', 'Expected vip or svip');
    }
    if (tier <= 0) {
      throw RangeError.value(tier, 'tier', 'Tier must be positive');
    }
    final isSvip = kind == 'svip';
    const base = 'assets/willchill_premium';
    final seed = tier + (isSvip ? 2 : 0);
    final backdrop = _pick(seed, isSvip ? 8 : 7, 0);
    final avatar = _pick(seed, 5, 0);
    final entry = _pick(seed, 5, 1);
    final chat = _pick(seed, 5, 2);
    final mic = _pick(seed, 5, 3);
    final profile = _pick(seed, 5, 4);
    final id = _pick(seed, 7, 2);
    final suffix = id == 1 ? '' : '_v$id';
    final useChatroom = tier.isOdd;

    return <MembershipPackArtwork>[
      MembershipPackArtwork(
        'Tier background',
        isSvip
            ? '$base/svip/bg_svip${backdrop}_frosted.webp'
            : '$base/vip/bg_vip${backdrop}_top_bg_res.webp',
        source: 'WillChill ${kind.toUpperCase()} $backdrop',
        isTierSpecific: backdrop == tier,
      ),
      MembershipPackArtwork(
        'Avatar frame',
        '$base/vip/icon_vip${avatar}_2.png',
        source: 'WillChill VIP $avatar',
        isTierSpecific: !isSvip && avatar == tier,
      ),
      MembershipPackArtwork(
        'ID nameplate',
        isSvip
            ? '$base/svip/voiceroom_icon_svip_id_left.webp'
            : '$base/vip/voiceroom_icon_vip_id_left$suffix.png',
        otherSide: isSvip
            ? '$base/svip/voiceroom_icon_svip_id_right.webp'
            : '$base/vip/voiceroom_icon_vip_id_right$suffix.png',
        source: isSvip ? 'WillChill shared SVIP ornaments' : 'WillChill VIP $id',
        isTierSpecific: !isSvip && id == tier,
      ),
      MembershipPackArtwork(
        'Entry banner',
        '$base/vip/icon_vip${entry}_3.png',
        source: 'WillChill VIP $entry (static banner)',
        isTierSpecific: !isSvip && entry == tier,
      ),
      MembershipPackArtwork(
        'Chat bubble',
        '$base/vip/icon_vip${chat}_4.png',
        source: 'WillChill VIP $chat',
        isTierSpecific: !isSvip && chat == tier,
      ),
      MembershipPackArtwork(
        'Mic effect',
        '$base/vip/icon_vip${mic}_5.png',
        source: 'WillChill VIP $mic (static image)',
        isTierSpecific: !isSvip && mic == tier,
      ),
      MembershipPackArtwork(
        'Profile decoration',
        '$base/vip/icon_vip${profile}_6.${profile == 1 ? 'webp' : 'png'}',
        source: 'WillChill VIP $profile',
        isTierSpecific: !isSvip && profile == tier,
      ),
      MembershipPackArtwork(
        'Room background',
        'assets/premium_store/danglive/${useChatroom ? 'chatroom-bg.png' : 'erbil-bg.png'}',
        source: useChatroom ? 'DangLive chatroom background' : 'DangLive Erbil background',
      ),
    ];
  }
}

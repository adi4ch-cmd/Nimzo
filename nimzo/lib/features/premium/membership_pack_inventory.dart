/// Original membership art is strictly locked to *both* kind and tier.
/// Different source APKs are fine; VIP 6 never borrows VIP 5 or SVIP 6.
/// Absence is honest (null), not a fake asset or another tier's artwork.
class MembershipPackArtwork {
  const MembershipPackArtwork._(
    this.title, this.path, this.source, this.sourceKind, this.sourceTier,
    {this.otherSide});

  /// Validates provenance even in release builds (not just Dart asserts).
  factory MembershipPackArtwork.matching({
    required String title,
    required String targetKind,
    required int targetTier,
    required String sourceKind,
    required int sourceTier,
    required String path,
    required String source,
    String? otherSide,
  }) {
    if (targetKind != sourceKind || targetTier != sourceTier) {
      throw StateError(
          'Cross-tier/cross-kind membership artwork rejected: '
          '$sourceKind $sourceTier cannot be used for $targetKind $targetTier');
    }
    return MembershipPackArtwork._(
        title, path, source, sourceKind, sourceTier, otherSide: otherSide);
  }

  const MembershipPackArtwork.missing(this.title)
      : path = null,
        otherSide = null,
        source = 'No same-kind, same-tier original found',
        sourceKind = null,
        sourceTier = null;

  final String title;
  final String? path;
  final String? otherSide;
  final String source;
  final String? sourceKind;
  final int? sourceTier;
  bool get available => path != null;
  bool get isTierSpecific => available && sourceKind != null && sourceTier != null;
  bool matchesTarget(String kind, int tier) =>
      !available || (sourceKind == kind && sourceTier == tier);
}

class MembershipPackInventory {
  static const slots = <String>[
    'Tier background',
    'Avatar frame',
    'ID nameplate',
    'Entry visual (static)',
    'Chat bubble',
    'Mic visual (static)',
    'Profile decoration',
    'Room background',
  ];

  /// Only use artwork confirmed to be labelled as this exact kind and tier.
  /// Hero/badge/card are resolved independently by the matching-tier
  /// membership presentation catalog (Falla/YoHo/Mizah).
  static List<MembershipPackArtwork> forTier(String kind, int tier) {
    if (kind != 'vip' && kind != 'svip') {
      throw ArgumentError.value(kind, 'kind', 'Expected vip or svip');
    }
    if (tier <= 0) throw RangeError.value(tier, 'tier');
    const root = 'assets/willchill_premium';
    final vip = kind == 'vip';
    final vipFull = vip && tier <= 5;
    final vipArt = vip && tier <= 7;
    final svipArt = !vip && tier <= 8;
    final suffix = tier == 1 ? '' : '_v$tier';

    MembershipPackArtwork pick(String title, String? path, {String? otherSide}) {
      if (path == null) return MembershipPackArtwork.missing(title);
      return MembershipPackArtwork.matching(
        title: title, targetKind: kind, targetTier: tier,
        sourceKind: kind, sourceTier: tier,
        source: 'WillChill $kind $tier', path: path, otherSide: otherSide);
    }

    return <MembershipPackArtwork>[
      pick('Tier background',
        vipArt ? '$root/vip/bg_vip${tier}_top_bg_res.webp'
          : svipArt ? '$root/svip/bg_svip${tier}_frosted.webp' : null),
      pick('Avatar frame',
        vipFull ? '$root/vip/icon_vip${tier}_2.png' : null),
      pick('ID nameplate',
        vipArt ? '$root/vip/voiceroom_icon_vip_id_left$suffix.png' : null,
        otherSide: vipArt
          ? '$root/vip/voiceroom_icon_vip_id_right$suffix.png' : null),
      pick('Entry visual (static)',
        vipFull ? '$root/vip/icon_vip${tier}_3.png'
          : svipArt ? '$root/svip/voiceroom_svip${tier}_entry_level_ic.webp'
          : null),
      pick('Chat bubble',
        vipFull ? '$root/vip/icon_vip${tier}_4.png' : null),
      pick('Mic visual (static)',
        vipFull ? '$root/vip/icon_vip${tier}_5.png' : null),
      pick('Profile decoration',
        vipFull ? '$root/vip/icon_vip${tier}_6.${tier == 1 ? 'webp' : 'png'}' : null),
      const MembershipPackArtwork.missing('Room background'),
    ];
  }
}

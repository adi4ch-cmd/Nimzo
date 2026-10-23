/// Original membership art is strictly locked to *both* kind and tier.
/// Different source APKs are fine; VIP 6 never borrows VIP 5 or SVIP 6.
/// Absence is honest (null), not a fake asset or another tier's artwork.
class MembershipPackArtwork {
  const MembershipPackArtwork._(
    this.title, this.path, this.source, this.sourceKind, this.sourceTier,
    {this.otherSide, this.thumbnail, this.format = 'image'});

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
    String? thumbnail,
    String format = 'image',
  }) {
    if (targetKind != sourceKind || targetTier != sourceTier) {
      throw StateError(
          'Cross-tier/cross-kind membership artwork rejected: '
          '$sourceKind $sourceTier cannot be used for $targetKind $targetTier');
    }
    return MembershipPackArtwork._(
        title, path, source, sourceKind, sourceTier,
        otherSide: otherSide, thumbnail: thumbnail, format: format);
  }

  const MembershipPackArtwork.missing(this.title)
      : path = null,
        otherSide = null,
        thumbnail = null,
        format = 'image',
        source = 'No same-kind, same-tier original found',
        sourceKind = null,
        sourceTier = null;

  final String title;
  final String? path;
  final String? otherSide;
  final String? thumbnail;
  final String format;
  bool get animated => format == 'svga';
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
    'Mic effect / visual',
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
    // Orii source media is verified in expanded Drive catalog and names its
    // exact SVIP tier; only those four tiers get this animated mic asset.
    // Actual Orii VIP 1–5 profile-card backgrounds, not screenshot crops.
    const vipProfileCard = <int, String>{
      1: 'assets/drive_catalog_expanded/8bec7620ab50b287621094e1a34a0cb0fb46c696416542ec2b010ee703987190.png',
      2: 'assets/drive_catalog_expanded/8c8d9e72c40cf2cb2536f8940c21b2b293c8e01c1a9d0f94456670a425ac01b7.png',
      3: 'assets/drive_catalog_expanded/b0be190d0a52adbccdffa213440cfbb6a274b4e4e5d8176b2d172cdeae301392.png',
      4: 'assets/drive_catalog_expanded/089423147c0410da9c26e138bcca5f7f5f676f5889897b45046b81b02e9e1498.png',
      5: 'assets/drive_catalog_expanded/90c5a63767f8b76151fdfaa6f533cb486226f4436d052e2a75eea906c3fb0b5b.png',
    };

    const svipMic = <int, (String, String)>{
      3: (
        'assets/drive_catalog_expanded/096e6ca992bb1ff8761f2b0fc6844375d46b01c0af8295592dd991a1d8d4d80f.svga',
        'assets/drive_catalog_expanded/eeb418e8623ef24fc16d9752f1103c45042f4a425194e55d994b9438c20f120e.png',
      ),
      4: (
        'assets/drive_catalog_expanded/2af1763a40b7510780820cfd2f25e039bf621e46df0f5427fb0caef31ebd6b1d.svga',
        'assets/drive_catalog_expanded/c2380fff578b5f27a48c6c09f117d248993d174ee59a6d56499cfb412c1882aa.png',
      ),
      5: (
        'assets/drive_catalog_expanded/c1cc37dc26d4f78b5c3626021f95ee12423c5e6494199b124a6194d6f09f7292.svga',
        'assets/drive_catalog_expanded/7b6a8b48920537247d8a78fb12dd35a571de36a7b92f12f0e91afd98c9e2bf54.png',
      ),
      6: (
        'assets/drive_catalog_expanded/e05d78c6b7ca7c384828c4fd240c2fb5a8e55ddd345c8afc82929030f58ce377.svga',
        'assets/drive_catalog_expanded/eaf13245e23e2be50b4601ae3af9a27fb8e9f78d92d56ff80ed71c696c47034b.png',
      ),
    };

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
      if (!vip && svipMic.containsKey(tier))
        MembershipPackArtwork.matching(
          title: 'Mic effect / visual',
          targetKind: kind, targetTier: tier,
          sourceKind: 'svip', sourceTier: tier,
          source: 'Orii SVIP $tier original mic_wave_svip$tier.svga',
          path: svipMic[tier]!.$1,
          thumbnail: svipMic[tier]!.$2,
          format: 'svga',
        )
      else
        pick('Mic effect / visual',
          vipFull ? '$root/vip/icon_vip${tier}_5.png' : null),
      if (vipProfileCard.containsKey(tier) && vip)
        MembershipPackArtwork.matching(
          title: 'Profile decoration',
          targetKind: kind, targetTier: tier,
          sourceKind: 'vip', sourceTier: tier,
          path: vipProfileCard[tier]!,
          source: 'Orii VIP $tier original profilecardbg',
        )
      else
        const MembershipPackArtwork.missing('Profile decoration'),
      const MembershipPackArtwork.missing('Room background'),
    ];
  }
}

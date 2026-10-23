import 'membership_original_assets.dart';

/// Original membership art is strictly locked to *both* kind and tier.
/// Different source APKs are fine; VIP 6 never borrows VIP 5 or SVIP 6.
/// Absence is honest (null), not a fake asset or another tier's artwork.
class MembershipPackArtwork {
  const MembershipPackArtwork._(
      this.title, this.path, this.source, this.sourceKind, this.sourceTier,
      {this.otherSide, this.thumbnail, this.crop, this.format = 'image'});

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
    List<double>? crop,
  }) {
    if (targetKind != sourceKind || targetTier != sourceTier) {
      throw StateError('Cross-tier/cross-kind membership artwork rejected: '
          '$sourceKind $sourceTier cannot be used for $targetKind $targetTier');
    }
    return MembershipPackArtwork._(title, path, source, sourceKind, sourceTier,
        otherSide: otherSide, thumbnail: thumbnail, crop: crop, format: format);
  }

  const MembershipPackArtwork.missing(this.title)
      : path = null,
        otherSide = null,
        thumbnail = null,
        crop = null,
        format = 'image',
        source = 'No same-kind, same-tier original found',
        sourceKind = null,
        sourceTier = null;

  final String title;
  final String? path;
  final String? otherSide;
  final String? thumbnail;

  /// Original canvas crop rectangle x,y,w,h,canvasW,canvasH. Bytes unchanged.
  final List<double>? crop;
  final String format;
  bool get animated => format == 'svga';
  final String source;
  final String? sourceKind;
  final int? sourceTier;
  bool get available => path != null;
  bool get isTierSpecific =>
      available && sourceKind != null && sourceTier != null;
  bool matchesTarget(String kind, int tier) =>
      !available || (sourceKind == kind && sourceTier == tier);
}

class MembershipPackInventory {
  static MembershipPackArtwork original(
      String kind, int tier, String slot, String title) {
    final row = membershipOriginalAssets['$kind$tier']?[slot];
    if (row == null) return MembershipPackArtwork.missing(title);
    return MembershipPackArtwork.matching(
        title: title,
        targetKind: kind,
        targetTier: tier,
        sourceKind: row['kind'] as String,
        sourceTier: row['tier'] as int,
        path: row['path'] as String,
        source: row['source'] as String,
        format: row['format'] as String,
        crop:
            (row['crop'] as List?)?.map((v) => (v as num).toDouble()).toList());
  }

  static MembershipPackArtwork profileCard(String kind, int tier) =>
      original(kind, tier, 'profile_card', 'Profile card');
  static MembershipPackArtwork medal(String kind, int tier) =>
      original(kind, tier, 'medal', 'Membership medal');
  static MembershipPackArtwork profileDecoration(String kind, int tier) =>
      original(
          kind, tier, 'profile_decoration_alternative', 'Profile decoration');
  static const slots = <String>[
    'Tier background',
    'Avatar frame',
    'ID nameplate',
    'Room entry effect / visual',
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
    final background = kind == 'svip' && tier <= 10
        ? MembershipPackArtwork.matching(
            title: slots[0],
            targetKind: kind,
            targetTier: tier,
            sourceKind: 'svip',
            sourceTier: tier,
            path: 'assets/membership/hafla/svip$tier-tier-background.png',
            source: 'Hafla bg_top_svip$tier.png')
        : kind == 'vip' && tier <= 7
            ? MembershipPackArtwork.matching(
                title: slots[0],
                targetKind: kind,
                targetTier: tier,
                sourceKind: 'vip',
                sourceTier: tier,
                path:
                    'assets/willchill_premium/vip/bg_vip${tier}_top_bg_res.webp',
                source: 'WillChill bg_vip${tier}_top_bg_res.webp')
            : MembershipPackArtwork.missing(slots[0]);
    const originals = {
      1: 'avatar_frame',
      2: 'nameplate',
      3: 'entrance_animation',
      4: 'chat_bubble',
      5: 'mic_animation',
      6: 'profile_decoration_alternative',
      7: 'room_background'
    };
    return [
      background,
      for (var i = 1; i < slots.length; i++)
        original(kind, tier, originals[i]!, slots[i])
    ];
  }
}

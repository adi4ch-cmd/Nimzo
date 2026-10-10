import 'package:flutter/material.dart';

/// Permissioned Haza decoration pack, rebranded for NIMZO screens.
///
/// The source contains exactly seven original VIP badge images, four VIP
/// stages/borders and SVIP decorative panels. It has NO tier 8-10 badges and
/// NO new SVIP tier medals. Never present a lower-tier badge as tier 8-10.
/// Until the original media ZIP is installed, use native NIMZO artwork.
class HazaMembershipArtwork {
  HazaMembershipArtwork._();
  static const vipRoot = 'assets/haza_membership/vip/';
  static const svipRoot = 'assets/haza_membership/svip/';

  static String? badge(int tier) =>
      tier >= 1 && tier <= 7 ? '${vipRoot}ic_vip_tag_$tier.png' : null;

  static String stage(int tier) {
    final group = tier <= 2 ? 1 : tier <= 4 ? 2 : tier <= 7 ? 3 : 4;
    return '${vipRoot}ic_vip_bg_$group.webp';
  }

  static String border(int tier) {
    final group = tier <= 2 ? 1 : tier <= 4 ? 2 : tier <= 7 ? 3 : 4;
    return '${vipRoot}ic_vip_border_$group.webp';
  }
}

class HazaVipBadge extends StatelessWidget {
  const HazaVipBadge({
    super.key,
    required this.tier,
    required this.size,
    required this.fallback,
  });

  final int tier;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final asset = HazaMembershipArtwork.badge(tier);
    if (asset == null) return fallback;
    // Direct asset resolution: avoid caching an empty AssetManifest during
    // cold-start or widget tests. Flutter's errorBuilder handles absent media.
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          asset,
          key: ValueKey('haza-vip-badge-$tier'),
          width: size,
          height: size * 80 / 196,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

/// Layer is decorative and does not grant purchase privileges or change levels.
class HazaMembershipStage extends StatelessWidget {
  const HazaMembershipStage({
    super.key,
    required this.tier,
    required this.svip,
  });

  final int tier;
  final bool svip;

  @override
  Widget build(BuildContext context) {
    final candidate = svip
        ? '${HazaMembershipArtwork.svipRoot}bg_svip_upgrade_dialog.webp'
        : HazaMembershipArtwork.stage(tier);
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              candidate,
              key: ValueKey(svip ? 'haza-svip-stage' : 'haza-vip-stage'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              color: const Color(0x5e090f15),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.expand(),
            ),
            if (!svip)
              Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  HazaMembershipArtwork.border(tier),
                  height: 20,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

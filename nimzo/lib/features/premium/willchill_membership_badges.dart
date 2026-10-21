import 'package:flutter/material.dart';
import 'dynamic_membership_media.dart';
import '../store/cosmetic_media_view.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// Real membership badges from the authenticated profile model.
/// SVIP artwork is available for tiers 1-8 and VIP artwork for 1-7 only.
/// Higher server-side membership levels are shown as text, not invented art.
class WillChillMembershipBadges extends StatefulWidget {
  const WillChillMembershipBadges({
    super.key,
    required this.svipLevel,
    required this.vipLevel,
    this.liveVipBadge,
    this.liveSvipBadge,
  });

  final int svipLevel;
  final int vipLevel;
  final NimzoMembershipMedia? liveVipBadge, liveSvipBadge;

  @override
  State<WillChillMembershipBadges> createState() =>
      _WillChillMembershipBadgesState();
}

class _WillChillMembershipBadgesState extends State<WillChillMembershipBadges> {
  late final Future<AssetManifest> _manifest =
      AssetManifest.loadFromAssetBundle(rootBundle);

  @override
  Widget build(BuildContext context) {
    final svip = widget.svipLevel;
    final vip = widget.vipLevel;
    if (svip <= 0 && vip <= 0) return const SizedBox.shrink();
    return FutureBuilder<AssetManifest>(
      future: _manifest,
      builder: (_, snapshot) {
        final known = snapshot.data?.listAssets().toSet() ?? const <String>{};
        Widget badge(String label, String path, Color tint,
            NimzoMembershipMedia? liveMedia) {
          final hasMedia = known.contains(path);
          return Semantics(
            label: label,
            child: liveMedia != null
                ? SizedBox(
                    height: 25,
                    width: 60,
                    child: CosmeticMediaView(
                      media: liveMedia.toCosmetic(),
                      animate: false,
                    ),
                  )
                : hasMedia
                ? Image.asset(path,
                    fit: BoxFit.contain,
                    height: 25,
                    errorBuilder: (_, __, ___) => Text(label))
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      child: Text(label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ),
                  ),
          );
        }

        return Wrap(
          key: const ValueKey('willchill-membership-badges'),
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (svip > 0)
              badge(
                  'SVIP $svip',
                  'assets/willchill_premium/svip/'
                      'voiceroom_svip${svip}_entry_level_ic.webp',
                  const Color(0xff7041ad), widget.liveSvipBadge),
            if (vip > 0)
              badge(
                  'VIP $vip',
                  'assets/willchill_premium/vip/ic_vip_leve$vip.png',
                  const Color(0xff996827), widget.liveVipBadge),
          ],
        );
      },
    );
  }
}

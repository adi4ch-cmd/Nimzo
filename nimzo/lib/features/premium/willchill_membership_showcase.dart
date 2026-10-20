import 'package:flutter/material.dart';

/// Member-facing SVIP/VIP presentation made from the bundled original artwork.
/// Selecting a tier is a visual preview only: never grants membership,
/// changes a wallet, or implies a server entitlement.
class WillChillMembershipShowcase extends StatelessWidget {
  const WillChillMembershipShowcase({
    super.key,
    required this.kind,
    required this.tier,
    required this.ownedLevel,
    required this.onTierChanged,
    this.onPreviewEntrance,
  });

  final String kind;
  final int tier;
  final int ownedLevel;
  final ValueChanged<int> onTierChanged;
  final VoidCallback? onPreviewEntrance;

  bool get _svip => kind == 'svip';
  int get _maxTier => _svip ? 8 : 7;
  String get _label => _svip ? 'SVIP' : 'VIP';
  String get _base => 'assets/willchill_premium/$kind/';

  Widget _art(String file, {double? height, BoxFit fit = BoxFit.contain}) {
    return Image.asset(
      '$_base$file',
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height ?? 42,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.white54),
        ),
      ),
    );
  }

  String get _heroImage =>
      _svip ? 'fixed_top_svip${tier}_bg.webp' : 'bg_vip${tier}_top_bg_res.webp';

  String get _medalImage => _svip
      ? 'voiceroom_svip${tier}_entry_level_ic.webp'
      : 'ic_vip_leve$tier.png';

  String get _privilegeArt => _svip
      ? 'bg_privil_item_svip$tier.webp'
      : 'bg_privil_item_vip$tier.${tier >= 6 ? 'png' : 'webp'}';

  @override
  Widget build(BuildContext context) {
    final owned = ownedLevel >= tier;
    const gold = Color(0xffefc983);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            key: ValueKey('willchill-${kind}-tier-strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            itemCount: _maxTier,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, index) {
              final level = index + 1;
              final selected = tier == level;
              return ChoiceChip(
                key: ValueKey('willchill-$kind-level-$level'),
                selected: selected,
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                label: Text('$_label $level', style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
                selectedColor: gold,
                onSelected: (_) => onTierChanged(level),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff39241c), Color(0xff170e14)],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _art(_heroImage, height: 308, fit: BoxFit.contain),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xed160e12)],
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          height: 54,
                          child: _art(_medalImage, height: 54),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_label $tier',
                              key: ValueKey('willchill-current-preview-$kind'),
                              style: const TextStyle(color: gold,
                                fontSize: 22, fontWeight: FontWeight.w800)),
                            Text(owned ? 'Your membership tier' : 'Tier preview',
                              style: const TextStyle(color: Colors.white70,
                                fontSize: 12)),
                          ],
                        )),
                        Icon(owned ? Icons.verified : Icons.lock_outline,
                          color: gold, size: 22),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text('Your $_label membership', style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xff26201c))),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xfffff9ee),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffe6cfad)),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: Color(0xff926824)),
              const SizedBox(width: 9),
              Expanded(child: Text(
                ownedLevel > 0
                    ? 'Current $_label level: $ownedLevel'
                    : 'No active $_label tier on your NIMZO account',
                style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 12, color: Color(0xff624824)),
              )),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text('$_label $tier appearance', style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xff26201c))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xfff8f1e8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            _art(_privilegeArt, height: 125),
            const SizedBox(height: 8),
            const Text('Original theme artwork preview',
              style: TextStyle(color: Color(0xff706459), fontSize: 12)),
          ]),
        ),
        if (_svip && onPreviewEntrance != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            key: ValueKey('willchill-svip-crown-$tier'),
            onPressed: onPreviewEntrance,
            icon: const Icon(Icons.play_circle_outline),
            label: Text('Preview SVIP $tier entrance'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff6c3e31),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Selecting a preview does not unlock SVIP or VIP. '
          'Membership levels and room privileges use verified NIMZO account data.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff786f67), fontSize: 11),
        ),
      ],
    );
  }
}

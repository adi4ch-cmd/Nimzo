import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'store_live_catalog.dart';

/// The selected free Avatar Frame becomes visible on the account's own
/// Me/Profile avatar, rather than stopping at a database-only equip button.
final nimzoOwnAvatarFrameProvider = Provider<int?>((ref) {
  final snapshot = ref.watch(nimzoStoreProvider).valueOrNull;
  if (snapshot == null) return null;
  final equippedId = snapshot.equipped['Avatar Frame'];
  if (equippedId == null) return null;
  for (final item in snapshot.items) {
    if (item.id == equippedId && snapshot.owned.contains(item.id)) {
      return item.variant;
    }
  }
  return null;
});

class NimzoEquippedAvatarFrame extends StatelessWidget {
  const NimzoEquippedAvatarFrame({
    super.key,
    required this.avatar,
    required this.variant,
  });

  final Widget avatar;
  final int? variant;

  @override
  Widget build(BuildContext context) {
    final v = variant;
    if (v == null) return avatar;
    const colors = <Color>[
      Color(0xffd29e34), Color(0xffdd6d9a), Color(0xffe79167),
      Color(0xff8666dc), Color(0xff149e85), Color(0xff438ec8),
      Color(0xffa6772d),
    ];
    final accent = colors[v % colors.length];
    return DecoratedBox(
      key: const ValueKey('equipped-nimzo-avatar-frame'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [
          accent,
          const Color(0xffffe9a2),
          accent,
          const Color(0xffffe9a2),
          accent,
        ]),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .22),
            blurRadius: 7, spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: avatar,
          ),
        ),
      ),
    );
  }
}

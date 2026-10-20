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


/// Royal Badge is only displayed after a real Collect + Equip operation.
final nimzoOwnRoyalBadgeProvider = Provider<int?>((ref) {
  final snapshot = ref.watch(nimzoStoreProvider).valueOrNull;
  if (snapshot == null) return null;
  final equippedId = snapshot.equipped['Royal Badge'];
  if (equippedId == null || !snapshot.owned.contains(equippedId)) return null;
  for (final item in snapshot.items) {
    if (item.id == equippedId && item.category == 'Royal Badge') {
      return item.variant;
    }
  }
  return null;
});

class NimzoEquippedRoyalBadge extends StatelessWidget {
  const NimzoEquippedRoyalBadge({super.key, this.variant});
  final int? variant;

  @override
  Widget build(BuildContext context) {
    final v = variant;
    if (v == null) return const SizedBox.shrink();
    const accents = <Color>[
      Color(0xffbd872a), Color(0xffe26aa7), Color(0xffdb7253),
      Color(0xff7660cd), Color(0xff0e9f84), Color(0xff378bbb),
      Color(0xffb7853b),
    ];
    final accent = accents[v % accents.length];
    return Container(
      key: const ValueKey('equipped-nimzo-royal-badge'),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          accent.withValues(alpha: .2),
          const Color(0xffffedbb),
        ]),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: .5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.workspace_premium_rounded, color: accent, size: 13),
        const SizedBox(width: 4),
        Text('ROYAL', style: TextStyle(
          color: accent, fontSize: 10, letterSpacing: 1,
          fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

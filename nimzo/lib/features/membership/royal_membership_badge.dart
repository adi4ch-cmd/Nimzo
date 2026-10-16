import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'royal_membership_repository.dart';

/// One backed identity badge, shared by Me, public profile and room cards.
class RoyalIdentityBadge extends ConsumerWidget {
  final String userId;
  final bool compact;
  const RoyalIdentityBadge({
    super.key, required this.userId, this.compact = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(freeRoyalSelectionProvider(userId))
        .valueOrNull?.visibleTheme;
    if (theme == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Free ${theme.label} member',
      child: Container(
        key: ValueKey('royal-member-$userId'),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.shadow, const Color(0xff13121c)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.accent, width: 1),
          boxShadow: [
            BoxShadow(color: theme.accent.withValues(alpha: .25), blurRadius: 9),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.workspace_premium, size: compact ? 12 : 16, color: theme.accent),
          const SizedBox(width: 3),
          Text(theme.label, style: TextStyle(
            fontSize: compact ? 10 : 12,
            color: theme.accent, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Real equipped native Flutter halo (separate from future media-based effects).
class RoyalAvatarHalo extends ConsumerWidget {
  final String userId;
  final Widget child;

  const RoyalAvatarHalo({
    super.key, required this.userId, required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(freeRoyalSelectionProvider(userId))
        .valueOrNull?.visibleTheme;
    if (theme == null) return child;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1100),
      tween: Tween(begin: .4, end: 1),
      builder: (context, intensity, content) => Container(
        key: ValueKey('royal-avatar-halo-$userId'),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            theme.accent.withValues(alpha: intensity),
            theme.shadow,
            theme.accent.withValues(alpha: .8),
            theme.shadow,
            theme.accent.withValues(alpha: intensity),
          ]),
          boxShadow: [
            BoxShadow(color: theme.accent.withValues(alpha: .25 * intensity),
              blurRadius: 11),
          ],
        ),
        child: content,
      ),
      child: child,
    );
  }
}

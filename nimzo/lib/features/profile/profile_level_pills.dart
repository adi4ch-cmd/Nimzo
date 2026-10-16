import 'package:flutter/material.dart';

import 'profile_level_scale.dart';

/// Compact, server-backed level badges for Me and in-room user cards.
/// Never substitutes guessed levels for unavailable backend values.
class ProfileLevelPill extends StatelessWidget {
  const ProfileLevelPill({
    super.key,
    required this.kind,
    required this.level,
    this.compact = true,
  }) : assert(kind >= 0 && kind < 3);

  final int kind;
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = ProfileLevelScale.color(kind, level);
    final icon = switch (kind) {
      0 => Icons.diamond,
      1 => Icons.favorite,
      _ => Icons.auto_awesome,
    };
    final label = ProfileLevelScale.labels[kind];
    return Semantics(
      label: '$label level ${level > 0 ? level : 'unavailable'}',
      child: Container(
        key: ValueKey('profile-level-pill-$kind'),
        constraints: const BoxConstraints(minHeight: 25),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 3),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 14 : 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              level > 0 ? '$level' : '—',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

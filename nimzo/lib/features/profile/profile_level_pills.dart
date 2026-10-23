import 'package:flutter/material.dart';

import 'falla_level_badge.dart';
import 'profile_level_scale.dart';

/// Exact Falla level artwork on Me, profile, chat and room cards.
/// For an unavailable asset, retain the existing NIMZO server-level fallback.
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
    final label = ProfileLevelScale.labels[kind];
    final tint = ProfileLevelScale.color(kind, level);
    final icon = switch (kind) {
      0 => Icons.diamond,
      1 => Icons.favorite,
      _ => Icons.auto_awesome,
    };
    final legacy = Container(
      constraints: const BoxConstraints(minHeight: 22, maxHeight: 34),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: 2),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 12 : 14, color: Colors.white),
        const SizedBox(width: 3),
        Text(level >= 0 ? '$level' : '—', style: TextStyle(
            color: Colors.white, fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w800)),
      ]),
    );
    return Semantics(
      label: '$label level ${level >= 0 ? level : 'unavailable'}',
      child: SizedBox(
        key: ValueKey('profile-level-pill-$kind'),
        height: compact ? 25 : 34,
        child: FallaLevelBadge(
          kind: kind,
          level: level,
          height: compact ? 25 : 34,
          fallback: legacy,
        ),
      ),
    );
  }
}

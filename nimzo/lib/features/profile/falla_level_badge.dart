import 'package:flutter/material.dart';

/// Original licensed Falla v9.23.0 level tag artwork extracted from base.apk.
/// Kinds: Wealth=0 (0-270), Charm=1 (0-270), Active=2 (0-140).
/// Never renders a made-up higher-tier image.
class FallaLevelBadge extends StatelessWidget {
  const FallaLevelBadge({
    super.key,
    required this.kind,
    required this.level,
    this.height = 30,
    this.fallback,
  });

  final int kind;
  final int level;
  final double height;
  final Widget? fallback;

  static const maxLevels = [270, 270, 140];
  static const categories = ['wealth', 'charm', 'active'];

  static bool isAvailable(int kind, int level) =>
      kind >= 0 && kind < 3 && level >= 0 && level <= maxLevels[kind];

  static String assetFor(int kind, int level) {
    if (!isAvailable(kind, level)) {
      throw RangeError('Falla badge not available for kind=$kind level=$level');
    }
    return 'assets/falla_levels/${categories[kind]}/$level.webp';
  }

  @override
  Widget build(BuildContext context) {
    if (!isAvailable(kind, level)) {
      return fallback ?? const SizedBox.shrink();
    }
    return Semantics(
      label: '${const ['Wealth', 'Charm', 'Active'][kind]} level $level',
      child: Image.asset(
        assetFor(kind, level),
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => fallback ?? Text('Lv. $level'),
      ),
    );
  }
}

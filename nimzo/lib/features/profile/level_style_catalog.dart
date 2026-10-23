import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/nimzo_content_sync.dart';

/// Approved presentation only. Neither XP, a level nor entitlement can be
/// supplied through this catalog. Missing/rejected configuration uses the
/// original local level artwork at the call site.
final profileLevelStylesProvider = Provider<LevelStyleCatalog>((ref) {
  final settings = ref.watch(nimzoRemoteSettingsProvider).valueOrNull;
  return LevelStyleCatalog.parse(settings?['progression.styles']);
});

class LevelBadgeStyle {
  const LevelBadgeStyle._({
    required this.kind,
    required this.minLevel,
    required this.maxLevel,
    required this.color,
    required this.glyph,
    required this.shape,
  });

  final int kind, minLevel, maxLevel;
  final Color color;
  final IconData glyph;
  final String shape;

  double get radius => switch (shape) {
        'rounded' => 7,
        'square' => 4,
        _ => 16,
      };
}

/// Bounded versioned presentation grammar. One malformed or conflicting band
/// rejects the complete payload, so partial publication never picks a winner.
class LevelStyleCatalog {
  const LevelStyleCatalog._(this.styles);
  static const empty = LevelStyleCatalog._([]);
  final List<LevelBadgeStyle> styles;

  static const kinds = {'wealth': 0, 'charm': 1, 'active': 2};
  static const palette = <String, Color>{
    'emerald': Color(0xff087f5b),
    'sapphire': Color(0xff2459b8),
    'ruby': Color(0xffbb3545),
    'amethyst': Color(0xff7651a8),
    'amber': Color(0xff95620c),
    'rose': Color(0xffb43875),
    'slate': Color(0xff526577),
  };
  static const glyphs = <String, IconData>{
    'diamond': Icons.diamond,
    'heart': Icons.favorite,
    'sparkle': Icons.auto_awesome,
    'shield': Icons.shield_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
  };
  static const shapes = {'pill', 'rounded', 'square'};
  static const _fields = {
    'kind',
    'min_level',
    'max_level',
    'color',
    'glyph',
    'shape',
  };

  static LevelStyleCatalog parse(Object? payload) {
    if (payload is! Map ||
        payload.length != 2 ||
        payload['version'] is! int ||
        payload['version'] != 1 ||
        !payload.containsKey('styles')) return empty;
    final rows = payload['styles'];
    if (rows is! List || rows.length > 36) return empty;
    final result = <LevelBadgeStyle>[];
    for (final row in rows) {
      if (row is! Map ||
          row.length != _fields.length ||
          !row.keys.every(_fields.contains)) return empty;
      final kind = kinds[row['kind']];
      final min = row['min_level'], max = row['max_level'];
      final color = palette[row['color']];
      final glyph = glyphs[row['glyph']];
      final shape = row['shape'];
      if (kind == null ||
          min is! int ||
          max is! int ||
          min < 1 ||
          max > 120 ||
          min > max ||
          color == null ||
          glyph == null ||
          !shapes.contains(shape)) return empty;
      if (result
          .any((s) => s.kind == kind && min <= s.maxLevel && max >= s.minLevel))
        return empty;
      result.add(LevelBadgeStyle._(
          kind: kind,
          minLevel: min,
          maxLevel: max,
          color: color,
          glyph: glyph,
          shape: shape as String));
    }
    return LevelStyleCatalog._(List.unmodifiable(result));
  }

  LevelBadgeStyle? resolve(int kind, int authoritativeLevel) {
    if (kind < 0 ||
        kind > 2 ||
        authoritativeLevel < 1 ||
        authoritativeLevel > 120) return null;
    for (final style in styles) {
      if (style.kind == kind &&
          authoritativeLevel >= style.minLevel &&
          authoritativeLevel <= style.maxLevel) return style;
    }
    return null;
  }
}

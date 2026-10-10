import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tier n starts at (n - 1)^2 * [unit]. The backend derives the displayed
/// level from the authoritative profile counters with this same contract.
class ProfileLevelScale {
  ProfileLevelScale._();
  static const labels = ['Wealth', 'Charm', 'Active'];
  static const units = ['coins sent', 'diamonds received', 'activity points'];
  static const thresholds = [10000, 100, 20];

  static int levelFor(int kind, int total) {
    final n = math.max(0, total);
    final base = math.sqrt(n / thresholds[kind]).floor() + 1;
    return base.clamp(1, 120);
  }

  static int requiredFor(int kind, int level) {
    final n = (level - 1).clamp(0, 119);
    return n * n * thresholds[kind];
  }

  static int nextRequirement(int kind, int level) =>
      level >= 120 ? requiredFor(kind, 120)
          : level * level * thresholds[kind];

  static double fraction(int kind, int level, int total) {
    if (level >= 120) return 1;
    final start = requiredFor(kind, level);
    final end = nextRequirement(kind, level);
    if (end <= start) return 0;
    return ((total - start) / (end - start)).clamp(0.0, 1.0);
  }

  static const _wealthColors = [
    Color(0xffa16207), Color(0xff16a34a), Color(0xff2563eb),
    Color(0xffdb2777), Color(0xffdc2626), Color(0xffd4a017),
  ];
  // Distinct rotations: level 1 is brown for wealth, blue for charm,
  // and red for active. Higher bands all change with actual level.
  static int band(int level) {
    if (level <= 20) return 0;
    if (level <= 39) return 1;
    if (level <= 59) return 2;
    if (level <= 79) return 3;
    if (level <= 99) return 4;
    return 5;
  }

  static Color color(int kind, int level) {
    if (level < 1 || level > 120 || kind < 0 || kind > 2) {
      return const Color(0xff64748b);
    }
    return _wealthColors[(band(level) + const [0, 2, 4][kind]) % 6];
  }
}

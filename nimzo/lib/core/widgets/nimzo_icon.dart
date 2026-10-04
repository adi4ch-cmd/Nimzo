import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Nimzo's professional icon language: restrained color accents instead of
/// emoji/unicode symbols. Each semantic icon keeps the same visual weight.
class NimzoIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final Color? color;

  const NimzoIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ??
        (active ? NimzoColors.primary : NimzoColors.textSecondary);
    return Icon(icon, size: size, color: accent);
  }
}

class NimzoNavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  const NimzoNavIcon(this.icon, {super.key, required this.active});

  @override
  Widget build(BuildContext context) => NimzoIcon(
        icon,
        size: 23,
        active: active,
      );
}

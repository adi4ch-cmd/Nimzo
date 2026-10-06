import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Lightweight pulsing placeholder list (no extra package).
class ShimmerView extends StatefulWidget {
  final int rows;
  const ShimmerView({super.key, this.rows = 6});
  @override
  State<ShimmerView> createState() => _S();
}

class _S extends State<ShimmerView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: .4, end: 1.0).animate(_c),
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.rows,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: NimzoColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

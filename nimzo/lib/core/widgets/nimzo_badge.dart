import 'package:flutter/material.dart';

import '../theme/colors.dart';

class NimzoBadge extends StatelessWidget {
  final String label;
  final bool gold;
  const NimzoBadge(this.label, {super.key, this.gold = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: gold ? NimzoColors.gold : NimzoColors.primaryLight,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: gold ? Colors.black87 : NimzoColors.primaryDark,
      ),
    ),
  );
}

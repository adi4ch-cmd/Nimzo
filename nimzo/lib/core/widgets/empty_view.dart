import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'nimzo_icon.dart';

class EmptyView extends StatelessWidget {
  final String title;
  final String? hint;
  final IconData icon;
  const EmptyView({
    super.key,
    required this.title,
    this.hint,
    this.icon = Icons.inbox,
  });
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: NimzoColors.primaryFaint,
                  shape: BoxShape.circle,
                ),
                child:
                    NimzoIcon(icon, size: 28, color: NimzoColors.primaryDark),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        )),
      );
}

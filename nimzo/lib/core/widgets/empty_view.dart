import 'package:flutter/material.dart';
import '../theme/colors.dart';

class EmptyView extends StatelessWidget {
  final String title;
  final String? hint;
  final IconData icon;
  const EmptyView(
      {super.key, required this.title, this.hint, this.icon = Icons.inbox});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: NimzoColors.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
      );
}

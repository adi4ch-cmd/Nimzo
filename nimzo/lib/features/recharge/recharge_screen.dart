import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/reference_widgets.dart';
import 'recharge_repository.dart';

class RechargeScreen extends ConsumerWidget {
  const RechargeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Recharge')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ReferenceCard(child: Text('1 USD = 500,000 coins')),
            AsyncContent(
              value: ref.watch(packagesProvider),
              onRetry: () => ref.invalidate(packagesProvider),
              builder: (rows) => rows.isEmpty
                  ? const EmptyContent('No recharge packages available')
                  : Column(
                      children: [
                        for (final r in rows)
                          ListTile(
                            title: Text('${r['coins']} coins'),
                            subtitle: Text(
                              'USD ${((r['usd_cents'] as num) / 100).toStringAsFixed(2)}',
                            ),
                          ),
                      ],
                    ),
            ),
            const EmptyContent(
              'Payments are unavailable until store products and receipt verification are verified.',
            ),
          ],
        ),
      );
}

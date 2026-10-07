import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/reference_widgets.dart';
import 'vip_repository.dart';

class VipScreen extends ConsumerWidget {
  final bool svip;
  const VipScreen({super.key, this.svip = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(svip ? 'SVIP' : 'VIP')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AsyncContent(
              value: ref.watch(vipStatusProvider),
              onRetry: () => ref.invalidate(vipStatusProvider),
              builder: (s) => ReferenceCard(
                child: Text(
                  '${svip ? 'SVIP' : 'VIP'} level: ${s[svip ? 'svip_level' : 'vip_level'] ?? 0}',
                ),
              ),
            ),
            AsyncContent(
              value: ref.watch(
                svip ? svipFridayRewardsProvider : vipDailyRewardsProvider,
              ),
              onRetry: () => ref.invalidate(
                svip ? svipFridayRewardsProvider : vipDailyRewardsProvider,
              ),
              builder: (rows) => Column(
                children: [
                  for (final r in rows)
                    ReferenceCard(
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/reference/${svip ? 'svip' : 'vip'}/${(r['level'] as int) - 1}.jpg',
                            width: 58,
                            height: 58,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${svip ? 'SVIP' : 'VIP'} ${r['level']} · ${r['coins']} coins',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const EmptyContent(
              'Membership purchase is unavailable until the current catalog and payment service are verified.',
            ),
          ],
        ),
      );
}

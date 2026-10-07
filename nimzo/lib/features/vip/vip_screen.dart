import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/nimzo_button.dart';
import '../../core/widgets/nimzo_icon.dart';
import 'vip_repository.dart';
import '../wallet/wallet_screen.dart';

class VipScreen extends ConsumerWidget {
  const VipScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void msg(String s) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    return Scaffold(
      appBar: AppBar(title: const Text('VIP & SVIP')),
      body: ref
          .watch(vipStatusProvider)
          .when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(vipStatusProvider),
            ),
            data: (s) {
              final vip = (s['vip_level'] as num?)?.toInt() ?? 0;
              final svip = (s['svip_level'] as num?)?.toInt() ?? 0;
              final expiry = s['vip_expires_at']?.toString();
              final vipProgress = (vip / 10).clamp(0.0, 1.0);
              final svipProgress = (svip / 10).clamp(0.0, 1.0);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(vipStatusProvider);
                  await ref.read(vipStatusProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TierCard(
                      icon: Icons.workspace_premium_rounded,
                      title: 'VIP',
                      level: vip,
                      detail: expiry == null ? 'Not active' : 'Expires $expiry',
                      progress: vipProgress,
                    ),
                    const SizedBox(height: 12),
                    _TierCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'SVIP',
                      level: svip,
                      detail: svip == 0 ? 'Not active' : '90-day cycle',
                      progress: svipProgress,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Normal VIP levels — coin prices',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const _VipPriceCatalog(),
                    const SizedBox(height: 16),
                    Text(
                      'VIP daily rewards',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ref
                        .watch(vipDailyRewardsProvider)
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('$e'),
                          data: (rows) => Column(
                            children: [
                              for (final row in rows)
                                _RewardRow(
                                  level: row['level'],
                                  coins: row['coins'],
                                ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 16),
                    Text(
                      'SVIP levels — approved recharge and weekly rewards',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Reference prices only. Purchases require verified '
                      'server-side payments; Sunday 9 PM Saudi-time '
                      'automatic payouts are not active yet.',
                    ),
                    const SizedBox(height: 8),
                    const _SvipCatalog(),
                    const SizedBox(height: 20),
                    NimzoButton(
                      label: 'Claim daily VIP reward',
                      onPressed: vip > 0
                          ? () async {
                              try {
                                await ref
                                    .read(vipRepositoryProvider)
                                    .claimDaily();
                                msg('VIP reward claimed');
                                ref.invalidate(vipStatusProvider);
                                ref.invalidate(walletProvider);
                              } catch (e) {
                                msg('$e');
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'SVIP weekly rewards are scheduled for Sunday at 9:00 PM '
                        'Saudi time. Automatic payouts are not active yet; '
                        'the legacy Friday claim is disabled to avoid '
                        'incorrect or duplicate credits.',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  final int level;
  final double progress;
  const _TierCard({
    required this.icon,
    required this.title,
    required this.level,
    required this.detail,
    required this.progress,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFFF8E7),
              child: NimzoIcon(icon, color: const Color(0xFFE0A72E)),
            ),
            title: Text(
              '$title Level $level',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(detail),
            trailing: level > 0
                ? const NimzoIcon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E9B73),
                  )
                : const NimzoIcon(Icons.lock_rounded, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 6),
          const SizedBox(height: 4),
          Text(
            level > 0 ? 'Level $level / 10' : 'Unlock VIP benefits',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _RewardRow extends StatelessWidget {
  final dynamic level, coins;
  const _RewardRow({required this.level, required this.coins});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: const NimzoIcon(
      Icons.monetization_on_rounded,
      color: Color(0xFFE0A72E),
    ),
    title: Text('Level $level'),
    trailing: Text(
      '${coins ?? 0} coins',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// Approved 7 October tier reference. This is display-only; never credit coins
/// or change memberships based on client-side catalog values.
class _SvipCatalog extends StatelessWidget {
  const _SvipCatalog();

  static const rechargeUsd = <int>[
    50, 200, 500, 1000, 3000, 10000, 30000, 75000, 200000, 500000,
  ];
  static const weeklyCoins = <int>[
    2000000, 5000000, 10000000, 20000000, 40000000,
    80000000, 150000000, 250000000, 450000000, 800000000,
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < rechargeUsd.length; i++)
        ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2B2020),
            child: Text('${i + 1}',
              style: const TextStyle(color: Color(0xFFFFD27C))),
          ),
          title: Text('SVIP ${i + 1} · ${rechargeUsd[i]} USD'),
          subtitle: Text('${weeklyCoins[i]} coins / week'),
        ),
    ],
  );
}

/// Locked Normal VIP prices. Informational only: membership purchase must
/// be implemented as an authorized, atomic server-side wallet operation.
class _VipPriceCatalog extends StatelessWidget {
  const _VipPriceCatalog();

  static const coinPrices = <int>[
    1000000, 3000000, 8000000, 15000000, 30000000,
    60000000, 100000000, 200000000, 350000000, 600000000,
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < coinPrices.length; i++)
        ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE5F4E9),
            child: Text('${i + 1}',
              style: const TextStyle(color: Color(0xFF176B4C))),
          ),
          title: Text('VIP ${i + 1}'),
          subtitle: Text('${coinPrices[i]} coins'),
        ),
    ],
  );
}

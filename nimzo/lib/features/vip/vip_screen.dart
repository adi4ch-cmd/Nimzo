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
                      'SVIP Friday rewards',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ref
                        .watch(svipFridayRewardsProvider)
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
                    NimzoButton(
                      label: 'Claim SVIP Friday reward',
                      outlined: true,
                      onPressed: svip > 0
                          ? () async {
                              try {
                                await ref
                                    .read(vipRepositoryProvider)
                                    .claimSvipFriday();
                                msg('SVIP reward claimed');
                                ref.invalidate(vipStatusProvider);
                                ref.invalidate(walletProvider);
                              } catch (e) {
                                msg('$e');
                              }
                            }
                          : null,
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

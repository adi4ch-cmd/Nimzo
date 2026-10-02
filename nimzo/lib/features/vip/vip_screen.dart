import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/nimzo_button.dart';
import 'vip_repository.dart';

class VipScreen extends ConsumerWidget {
  const VipScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    return Scaffold(appBar: AppBar(title: const Text('VIP & SVIP')), body: ref.watch(vipStatusProvider).when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(vipStatusProvider)),
      data: (s) {
        final vip = (s['vip_level'] as num?)?.toInt() ?? 0;
        final svip = (s['svip_level'] as num?)?.toInt() ?? 0;
        final expiry = s['vip_expires_at']?.toString();
        return RefreshIndicator(onRefresh: () async { ref.invalidate(vipStatusProvider); await ref.read(vipStatusProvider.future); }, child: ListView(padding: const EdgeInsets.all(16), children: [
          _TierCard(icon: Icons.workspace_premium_rounded, title: 'VIP', level: vip, detail: expiry == null ? 'Not active' : 'Expires $expiry'),
          const SizedBox(height: 12),
          _TierCard(icon: Icons.auto_awesome_rounded, title: 'SVIP', level: svip, detail: svip == 0 ? 'Not active' : '90-day cycle'),
          const SizedBox(height: 20),
          Text('VIP daily rewards', style: Theme.of(context).textTheme.titleMedium),
          ref.watch(vipDailyRewardsProvider).when(loading: () => const LinearProgressIndicator(), error: (e, _) => Text('$e'), data: (rows) => Column(children: [for (final row in rows) _RewardRow(level: row['level'], coins: row['coins'])])),
          const SizedBox(height: 16),
          Text('SVIP Friday rewards', style: Theme.of(context).textTheme.titleMedium),
          ref.watch(svipFridayRewardsProvider).when(loading: () => const LinearProgressIndicator(), error: (e, _) => Text('$e'), data: (rows) => Column(children: [for (final row in rows) _RewardRow(level: row['level'], coins: row['coins'])])),
          const SizedBox(height: 20),
          NimzoButton(label: 'Claim daily VIP reward', onPressed: vip > 0 ? () async { try { await ref.read(vipRepositoryProvider).claimDaily(); msg('VIP reward claimed'); ref.invalidate(vipStatusProvider); } catch (e) { msg('$e'); } } : null),
          const SizedBox(height: 10),
          NimzoButton(label: 'Claim SVIP Friday reward', outlined: true, onPressed: svip > 0 ? () async { try { await ref.read(vipRepositoryProvider).claimSvipFriday(); msg('SVIP reward claimed'); ref.invalidate(vipStatusProvider); } catch (e) { msg('$e'); } } : null),
        ]));
      },
    ));
  }
}

class _TierCard extends StatelessWidget {
  final IconData icon; final String title, detail; final int level;
  const _TierCard({required this.icon, required this.title, required this.level, required this.detail});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text('$title Level $level', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(detail), trailing: level > 0 ? const Icon(Icons.check_circle_rounded) : const Icon(Icons.lock_outline_rounded)));
}

class _RewardRow extends StatelessWidget {
  final dynamic level, coins;
  const _RewardRow({required this.level, required this.coins});
  @override
  Widget build(BuildContext context) => ListTile(dense: true, leading: const Icon(Icons.monetization_on_rounded), title: Text('Level $level'), trailing: Text('${coins ?? 0} coins', style: const TextStyle(fontWeight: FontWeight.w600)));
}
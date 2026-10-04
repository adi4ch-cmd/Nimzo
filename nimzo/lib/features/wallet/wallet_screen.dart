import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/nimzo_icon.dart';

final walletProvider = FutureProvider((ref) async {
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  if (user == null) throw Exception('Not signed in');
  final w = await db.from('wallets').select().eq('user_id', user.id).single();
  final l = await db.from('ledger').select().order('created_at', ascending: false).limit(50);
  return (coins: w['coins'] as int, diamonds: w['diamonds'] as int, ledger: l);
});

class _BalanceTile extends StatelessWidget { final IconData icon; final String label, value; const _BalanceTile({required this.icon, required this.label, required this.value}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [CircleAvatar(radius: 18, backgroundColor: const Color(0xFFEFFAF4), child: NimzoIcon(icon, size: 19, color: const Color(0xFF2E9B73))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]))]))); }

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ref.watch(walletProvider).when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(walletProvider)),
        data: (w) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFDCFCE7))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your balance', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text('${w.coins}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${w.diamonds} diamonds', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _BalanceTile(icon: Icons.monetization_on_rounded, label: 'Coins', value: '${w.coins}')),
              const SizedBox(width: 10),
              Expanded(child: _BalanceTile(icon: Icons.diamond_rounded, label: 'Diamonds', value: '${w.diamonds}')),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => context.push('/recharge'), icon: const NimzoIcon(Icons.add_circle_rounded, color: Colors.white), label: const Text('Recharge'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/vip'), icon: const NimzoIcon(Icons.workspace_premium_rounded, color: Color(0xFFE0A72E)), label: const Text('VIP'))),
            ]),
          ],
        ),
      ),
    );
  }
}

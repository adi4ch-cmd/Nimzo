import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';

/// Read-only. Balances are never written from the client.
final walletProvider = FutureProvider((ref) async {
  final db = Supabase.instance.client;
  final w = await db.from('wallets').select().eq('user_id', db.auth.currentUser!.id).single();
  final l = await db.from('ledger').select().order('created_at', ascending: false).limit(50);
  return (coins: w['coins'] as int, diamonds: w['diamonds'] as int, ledger: l);
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: ref.watch(walletProvider).when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(walletProvider)),
              data: (w) => ListView(padding: const EdgeInsets.all(16), children: [
                Text('Coins: ${w.coins}', style: Theme.of(context).textTheme.headlineMedium),
                Text('Diamonds: ${w.diamonds}'),
                Row(children: [
                  TextButton(onPressed: () => context.push('/recharge'), child: const Text('Recharge')),
                  TextButton(onPressed: () => context.push('/vip'), child: const Text('VIP')),
                  TextButton(onPressed: () => context.push('/reseller'), child: const Text('Reseller')),
                ]),
                const Divider(height: 32),
                if (w.ledger.isEmpty) const EmptyView(title: 'No transactions yet'),
                for (final e in w.ledger)
                  ListTile(title: Text('${e['kind']}'), trailing: Text('${e['coin_delta']} / ${e['diamond_delta']}')),
              ]),
            ),
      );
}

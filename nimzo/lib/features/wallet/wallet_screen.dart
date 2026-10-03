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
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFDCFCE7))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Your balance', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 4), Text('${w.coins}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('${w.diamonds} diamonds', style: Theme.of(context).textTheme.bodySmall)]),
                Row(children: [
                  TextButton(onPressed: () => context.push('/recharge'), child: const Text('Recharge')),
                  TextButton(onPressed: () => context.push('/vip'), child: const Text('VIP')),
                                  ]),
                const SizedBox(height: 18),
                Row(children: [Expanded(child: FilledButton.icon(onPressed: () => context.push('/recharge'), icon: const Icon(Icons.add_rounded), label: const Text('Recharge'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/vip'), icon: const Icon(Icons.workspace_premium_outlined), label: const Text('VIP')))]),
              ]),
            ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/master_ui.dart';

final walletProvider = FutureProvider<({int coins, int diamonds})>((ref) async {
  final db = ref.watch(supabaseProvider);
  final id = ref.watch(currentUserIdProvider);
  if (id == null) throw StateError('Sign in required');
  final row = await db
      .from('wallets')
      .select('coins,diamonds')
      .eq('user_id', id)
      .single();
  return (
    coins: (row['coins'] as num).toInt(),
    diamonds: (row['diamonds'] as num).toInt(),
  );
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Wallet')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AsyncContent(
          value: ref.watch(walletProvider),
          onRetry: () => ref.invalidate(walletProvider),
          builder: (w) => Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: NimzoStyle.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coins', style: TextStyle(color: Colors.white)),
                Text(
                  referenceNumber(w.coins),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${w.diamonds} diamonds',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const ReferenceCard(child: Text('1 USD = 500,000 coins')),
        GradientButton(
          onPressed: () => context.push('/recharge'),
          child: const Text('Recharge'),
        ),
      ],
    ),
  );
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/master_ui.dart';

final walletProvider = FutureProvider.autoDispose<({int coins, int diamonds})>((ref) async {
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

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final amount = TextEditingController();
  bool exchanging = false;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> exchangeDiamonds(int available) async {
    if (exchanging) return;
    final requested = int.tryParse(amount.text.trim());
    if (requested == null || requested <= 0 || requested > available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid amount within your diamond balance.'),
      ));
      return;
    }
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exchange diamonds?'),
        content: Text(
          '${referenceNumber(requested)} diamonds will become '
          '${referenceNumber(requested)} coins at 1:1. '
          'This exchange cannot be reversed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exchange')),
        ],
      ),
    );
    if (confirmation != true || !mounted) return;
    setState(() => exchanging = true);
    final key = 'diamond-exchange-${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(0x7fffffff)}';
    try {
      await ref.read(sessionSupabaseProvider).client.rpc('exchange_diamonds',
        params: {'p_amount': requested, 'p_key': key});
      ref.invalidate(walletProvider);
      amount.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${referenceNumber(requested)} coins added.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Exchange failed. Please refresh wallet and retry.'),
        ));
      }
    } finally {
      if (mounted) setState(() => exchanging = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wallet')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AsyncContent(
          value: ref.watch(walletProvider),
          onRetry: () => ref.invalidate(walletProvider),
          builder: (w) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('wallet-coin-diamond-balances'),
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: NimzoStyle.gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Coins',
                      style: TextStyle(color: Colors.white)),
                    Text(referenceNumber(w.coins),
                      style: const TextStyle(color: Colors.white,
                        fontSize: 30, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text('Diamonds (earned from received gifts)',
                      style: TextStyle(color: Colors.white70)),
                    Text(referenceNumber(w.diamonds),
                      key: const ValueKey('wallet-diamonds'),
                      style: const TextStyle(color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const ReferenceCard(child: Text(
                'Received gifts pay 45% of their coin value in diamonds. '
                '1 diamond = 1 coin at exchange.',
              )),
              const SizedBox(height: 13),
              TextField(
                key: const ValueKey('exchange-diamond-amount'),
                controller: amount,
                enabled: !exchanging,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Diamonds to exchange',
                  hintText: 'Enter amount',
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: exchanging ? null : () =>
                      setState(() => amount.text = w.diamonds.toString()),
                    child: const Text('MAX'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('exchange-diamonds-1-to-1'),
                onPressed: exchanging || w.diamonds <= 0
                    ? null : () => exchangeDiamonds(w.diamonds),
                icon: const Icon(Icons.currency_exchange),
                label: Text(exchanging ? 'Exchanging…' : 'Exchange 1:1'),
              ),
              const SizedBox(height: 15),
              const ReferenceCard(child: Text('1 USD = 500,000 coins')),
              GradientButton(
                onPressed: () => context.push('/recharge'),
                child: const Text('Recharge'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'dart:async';
import 'diamond_exchange_session.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/master_ui.dart';

final walletProvider =
    FutureProvider.autoDispose<({int coins, int diamonds})>((ref) async {
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
  bool exchanging = false, restoring = false, storageFailed = false;
  String? account, exchangeError;
  int generation = 0;
  DiamondExchangeSession? exchange;

  void bind(String? user) {
    if (account == user) return;
    account = user;
    final epoch = ++generation;
    exchanging = false;
    storageFailed = false;
    exchangeError = null;
    amount.clear();
    exchange = user == null ? null : DiamondExchangeSession(user);
    restoring = exchange != null;
    final current = exchange;
    if (current == null) return;
    unawaited(() async {
      try {
        await current.restore();
        if (!mounted || epoch != generation) return;
        setState(() {
          restoring = false;
          if (current.pendingAmount != null)
            amount.text = '${current.pendingAmount}';
        });
      } catch (_) {
        if (mounted && epoch == generation)
          setState(() {
            restoring = false;
            storageFailed = true;
            exchangeError =
                'Previous exchange could not be safely recovered. Reopen Wallet to retry.';
          });
      }
    }());
  }

  bool same(int epoch) =>
      mounted &&
      epoch == generation &&
      ref.read(currentUserIdProvider) == exchange?.account;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> exchangeDiamonds(int available) async {
    final current = exchange;
    if (current == null || exchanging || restoring || storageFailed) return;
    final epoch = generation;
    final pending = current.pendingAmount != null;
    final requested = current.pendingAmount ?? int.tryParse(amount.text.trim());
    if (requested == null ||
        requested <= 0 ||
        (!pending && requested > available)) {
      setState(() =>
          exchangeError = 'Enter a valid amount within your diamond balance.');
      return;
    }
    setState(() {
      exchanging = true;
      exchangeError = null;
    });
    try {
      if (!pending) {
        final confirmation = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('Exchange diamonds?'),
                    content: Text(
                        '${referenceNumber(requested)} diamonds will become '
                        '${referenceNumber(requested)} coins at 1:1. This exchange cannot be reversed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Exchange')),
                    ]));
        if (confirmation != true || !same(epoch)) return;
      }
      if (!same(epoch)) return;
      final db = ref.read(sessionSupabaseProvider).client;
      await current.submit(requested, (params) async {
        if (!same(epoch)) throw StateError('Account changed');
        return Map<String, dynamic>.from(
            await db.rpc('exchange_diamonds_checked', params: params));
      });
      if (!same(epoch)) return;
      ref.invalidate(walletProvider);
      amount.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${referenceNumber(requested)} coins added.')));
    } catch (_) {
      if (same(epoch))
        setState(() => exchangeError = current.pendingAmount != null
            ? 'Exchange not confirmed. Retry the same exchange to recover its receipt.'
            : 'Exchange declined. Check your diamond balance and retry.');
    } finally {
      if (mounted && epoch == generation) setState(() => exchanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bind(ref.watch(currentUserIdProvider));
    return Scaffold(
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
                    gradient: NimzoStyle.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x238b3dff),
                        offset: Offset(0, 8),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.monetization_on_rounded,
                              size: 20, color: Color(0xffffcf79)),
                          SizedBox(width: 7),
                          Text('Coins',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(referenceNumber(w.coins),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white24, height: 1),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.diamond_rounded,
                              size: 20, color: Color(0xffffbedf)),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Diamonds (earned from received gifts)',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(referenceNumber(w.diamonds),
                          key: const ValueKey('wallet-diamonds'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const ReferenceCard(
                    child: Text(
                  'Received gifts pay 45% of their coin value in diamonds. '
                  '1 diamond = 1 coin at exchange.',
                )),
                const SizedBox(height: 13),
                TextField(
                  key: const ValueKey('exchange-diamond-amount'),
                  controller: amount,
                  enabled: !exchanging &&
                      !restoring &&
                      !storageFailed &&
                      exchange?.pendingAmount == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Diamonds to exchange',
                    hintText: 'Enter amount',
                    border: const OutlineInputBorder(),
                    suffixIcon: TextButton(
                      onPressed: exchanging ||
                              restoring ||
                              storageFailed ||
                              exchange?.pendingAmount != null
                          ? null
                          : () => setState(
                              () => amount.text = w.diamonds.toString()),
                      child: const Text('MAX'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('exchange-diamonds-1-to-1'),
                  onPressed: exchanging ||
                          restoring ||
                          storageFailed ||
                          exchange == null ||
                          (w.diamonds <= 0 && exchange?.pendingAmount == null)
                      ? null
                      : () => exchangeDiamonds(w.diamonds),
                  icon: const Icon(Icons.currency_exchange),
                  label: Text(restoring
                      ? 'Recovering exchange…'
                      : exchanging
                          ? 'Exchanging…'
                          : exchange?.pendingAmount != null
                              ? 'Retry same exchange'
                              : 'Exchange 1:1'),
                ),
                if (exchangeError != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(exchangeError!)),
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
}

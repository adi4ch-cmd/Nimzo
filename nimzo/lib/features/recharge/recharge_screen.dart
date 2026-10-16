import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../wallet/wallet_screen.dart';
import 'purchase_controller.dart';

class RechargeScreen extends ConsumerStatefulWidget {
  const RechargeScreen({super.key});
  @override
  ConsumerState<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends ConsumerState<RechargeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(purchaseControllerProvider).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(purchaseControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Coin store')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncContent(
            value: ref.watch(walletProvider),
            onRetry: () => ref.invalidate(walletProvider),
            builder: (wallet) => BalancePanel(
              label: 'Your coins',
              balance: referenceNumber(wallet.coins),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            checkout.store == 'google_play'
                ? 'Google Play checkout'
                : checkout.store == 'app_store'
                    ? 'App Store checkout'
                    : 'Mobile store checkout',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('Environment: ${checkout.environment}'),
          const SizedBox(height: 8),
          Text(checkout.message, key: const Key('checkout-status')),
          if (checkout.loading || checkout.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 12),
          for (final product in checkout.products)
            Card(
              child: ListTile(
                title: Text(
                  '${referenceNumber((checkout.packages[product.id]['coins'] as num))} coins',
                ),
                subtitle: Text(product.title),
                trailing: FilledButton(
                  onPressed: checkout.ready &&
                          !checkout.busy &&
                          !checkout.loading &&
                          !checkout.canRetry
                      ? () => checkout.buy(product)
                      : null,
                  child: Text(product.price),
                ),
              ),
            ),
          if (!checkout.busy)
            OutlinedButton(
              onPressed: checkout.loading ? null : checkout.load,
              child: const Text('Reload store'),
            ),
          if (!checkout.busy && checkout.store != null)
            TextButton(
              onPressed: checkout.retry,
              child: Text(
                checkout.canRetry
                    ? 'Retry payment verification'
                    : 'Check unfinished purchases',
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Sandbox purchases are not credited to live wallets. The store confirms the price and payment method before charging. Coins are credited only after server verification. If verification fails, retry it before buying again.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

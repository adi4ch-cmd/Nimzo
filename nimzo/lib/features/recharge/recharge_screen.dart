import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/theme/app_theme.dart';
import '../wallet/wallet_screen.dart';
import 'recharge_repository.dart';

class RechargeScreen extends ConsumerWidget {
  const RechargeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: AppBar(title: const Text('Recharge')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AsyncContent(
            value: ref.watch(walletProvider),
            onRetry: () => ref.invalidate(walletProvider),
            builder: (wallet) => BalancePanel(
                label: 'Your coins', balance: referenceNumber(wallet.coins))),
        const Padding(
            padding: EdgeInsets.fromLTRB(0, 6, 0, 8),
            child: Text('Choose amount',
                style: TextStyle(fontWeight: FontWeight.w700))),
        AsyncContent(
            value: ref.watch(packagesProvider),
            onRetry: () => ref.invalidate(packagesProvider),
            builder: (rows) => rows.isEmpty
                ? const EmptyContent('No recharge packages available')
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent:
                        94 * MediaQuery.textScalerOf(context).scale(1),
                    children: [
                        for (final r in rows)
                          InkWell(
                              onTap: () => showReferenceSheet(
                                  context,
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Pay \$${((r['usd_cents'] as num) / 100).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700)),
                                        for (final method in [
                                          'Card',
                                          'Google Pay / Apple Pay',
                                          'Local wallet'
                                        ])
                                          ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(method),
                                              trailing: const Icon(
                                                  Icons.chevron_right),
                                              onTap: () => showUiUnavailable(
                                                  context, 'Payment'))
                                      ])),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: NimzoStyle.surface,
                                      border:
                                          Border.all(color: NimzoStyle.line),
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                            '\$${((r['usd_cents'] as num) / 100).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            '${referenceNumber(r['coins'] as num)} coins',
                                            style: const TextStyle(
                                                color: NimzoStyle.primary,
                                                fontSize: 12))
                                      ])))
                      ])),
        const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
                '1 USD = 500,000 coins. Payment methods depend on your country. Coins are added only after the server verifies the payment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NimzoStyle.muted, fontSize: 12))),
      ]));
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import '../wallet/wallet_screen.dart';
import '../vip/vip_repository.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'recharge_repository.dart';
import '../../core/widgets/nimzo_icon.dart';

class RechargeScreen extends ConsumerStatefulWidget {
  const RechargeScreen({super.key});
  @override
  ConsumerState<RechargeScreen> createState() => _RechargeState();
}

class _RechargeState extends ConsumerState<RechargeScreen> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _storeReady = false;
  bool _busy = false;
  final Map<String, ProductDetails> _products = {};
  final Map<String, PurchaseDetails> _pending = {};
  final Set<String> _processing = {};
  final Set<String> _credited = {};

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Purchase error: $e')));
      },
    );
    _initStore();
  }

  Future<void> _initStore() async {
    try {
      final ok = await _iap.isAvailable();
      if (!ok) return;
      final packages = await ref.read(packagesProvider.future);
      final products = await _iap.queryProductDetails(
        packages.map((p) => p['product_id'].toString()).toSet(),
      );
      if (products.error != null) throw StateError(products.error!.message);
      if (mounted)
        setState(() {
          _storeReady = true;
          _products.addEntries(
            products.productDetails.map((p) => MapEntry(p.id, p)),
          );
        });
      // Unconsumed Android purchases and unfinished Apple transactions are retried safely.
      await _iap.restorePurchases();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Store unavailable: $e')));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _buy(Map<String, dynamic> p) async {
    if (!_storeReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'App Store / Google Play is not available right now.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final details = await _iap.queryProductDetails({
        p['product_id'].toString(),
      });
      if (details.notFoundIDs.isNotEmpty || details.productDetails.isEmpty) {
        throw StateError('This package is not available in the store yet.');
      }
      final product = details.productDetails.first;
      if (mounted) setState(() => _products[product.id] = product);
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: details.productDetails.first,
        ),
        autoConsume: false,
      );
      if (!started)
        throw StateError('The store could not start this purchase.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!mounted) return;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final key =
            '${purchase.productID}:${purchase.purchaseID ?? purchase.verificationData.serverVerificationData}';
        if (!_processing.add(key)) continue;
        _pending[key] = purchase;
        try {
          await ref
              .read(rechargeRepositoryProvider)
              .verify(
                store:
                    purchase.verificationData.source.toLowerCase().contains(
                      'app',
                    )
                    ? 'apple'
                    : 'google',
                productId: purchase.productID,
                receipt: purchase.verificationData.serverVerificationData,
                transactionId: purchase.purchaseID,
              );
          if (Platform.isAndroid) {
            final addition = _iap
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
            final consumed = await addition.consumePurchase(purchase);
            if (consumed.responseCode != BillingResponse.ok &&
                consumed.responseCode != BillingResponse.itemNotOwned) {
              throw StateError(
                'Coins credited; store finalization pending. Retry is safe.',
              );
            }
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _pending.remove(key);
          if (mounted) {
            ref.invalidate(walletProvider);
            ref.invalidate(vipStatusProvider);
          }
          if (mounted && _credited.add(key)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase verified and coins credited.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Verification pending: $e')));
          }
        } finally {
          _processing.remove(key);
        }
      } else if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _busy = true);
        continue;
      } else if (purchase.status == PurchaseStatus.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(purchase.error?.message ?? 'Purchase failed')),
        );
      }
    }
    if (mounted)
      setState(
        () => _busy = purchases.any((p) => p.status == PurchaseStatus.pending),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharge')),
      bottomNavigationBar: _pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _busy = true);
                          _onPurchases(_pending.values.toList());
                        },
                  child: const Text('Retry pending verification'),
                ),
              ),
            ),
      body: ref
          .watch(packagesProvider)
          .when(
            loading: () => const ShimmerView(),
            error: (e, _) => ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(packagesProvider),
            ),
            data: (packages) {
              if (packages.isEmpty) {
                return const EmptyView(title: 'No packages available');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: packages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final package = packages[i];
                  final product = _products[package['product_id'].toString()];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF8E7),
                        child: NimzoIcon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFFE0A72E),
                        ),
                      ),
                      title: Text('${package['coins']} coins'),
                      subtitle: const Text(
                        'Nimzo coins • 1 USD = 500,000 coins',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            product?.price ?? 'Unavailable',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Text('Buy', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      onTap: _busy || !_storeReady || product == null
                          ? null
                          : () => _buy(package),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

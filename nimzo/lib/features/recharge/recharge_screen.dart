import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'recharge_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase error: $e')));
    });
    _initStore();
  }

  Future<void> _initStore() async {
    final ok = await _iap.isAvailable();
    if (mounted) setState(() => _storeReady = ok);
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
          const SnackBar(content: Text('App Store / Google Play is not available right now.')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final details = await _iap.queryProductDetails({p['product_id'].toString()});
      if (details.notFoundIDs.isNotEmpty || details.productDetails.isEmpty) {
        throw StateError('This package is not available in the store yet.');
      }
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details.productDetails.first),
        autoConsume: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          await ref.read(rechargeRepositoryProvider).verify(
            store: purchase.verificationData.source.toLowerCase().contains('app')
                ? 'apple'
                : 'google',
            productId: purchase.productID,
            receipt: purchase.verificationData.serverVerificationData,
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase verified and coins credited.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification pending: $e')),
            );
          }
        }
      } else if (purchase.status == PurchaseStatus.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(purchase.error?.message ?? 'Purchase failed')),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharge')),
      body: ref.watch(packagesProvider).when(
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
              final price = ((package['usd_cents'] as num) / 100).toStringAsFixed(2);
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(child: Icon(Icons.monetization_on_rounded)),
                  title: Text('${package['coins']} coins'),
                  subtitle: const Text('Nimzo coins • \\$1 = 500,000 coins'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(r'$' + price, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Text('Buy', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  onTap: _busy ? null : () => _buy(package),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

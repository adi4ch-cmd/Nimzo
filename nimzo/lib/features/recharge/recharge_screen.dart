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
  @override ConsumerState<RechargeScreen> createState() => _RechargeState();
}

class _RechargeState extends ConsumerState<RechargeScreen> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _storeReady = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase error: $e')));
    });
    _initStore();
  }

  Future<void> _initStore() async {
    final ok = await _iap.isAvailable();
    if (mounted) setState(() => _storeReady = ok);
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  Future<void> _buy(Map<String, dynamic> p) async {
    if (!_storeReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App Store / Google Play is not available right now.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final details = await _iap.queryProductDetails({p['product_id'].toString()});
      if (details.notFoundIDs.isNotEmpty || details.productDetails.isEmpty) throw StateError('This package is not available in the store yet.');
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: details.productDetails.first), autoConsume: true);
    } catch (e) {
      if (mounted) { setState(() => _busy = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        try {
          await ref.read(rechargeRepositoryProvider).verify(
            store: p.verificationData.source.toLowerCase().contains('app') ? 'apple' : 'google',
            productId: p.productID, receipt: p.verificationData.serverVerificationData);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase verified and coins credited.')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification pending: $e')));
        }
      } else if (p.status == PurchaseStatus.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.error?.message ?? 'Purchase failed')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recharge')),
    body: ref.watch(packagesProvider).when(
      loading: () => const ShimmerView(),
      error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(packagesProvider)),
      data: (l) => l.isEmpty ? const EmptyView(title: 'No packages available') : ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = l[i];
          return Card(child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(child: const Icon(Icons.monetization_on_rounded)),
            title: Text('${p['coins']} coins'),
            subtitle: Text('Nimzo coins • $1 = 500,000 coins'),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('\${((p['usd_cents'] as num) / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)), const Text('Buy', style: TextStyle(fontSize: 12))]),
            onTap: _busy ? null : () => _buy(p),
          ));
        },
      ),
    ),
  );
}
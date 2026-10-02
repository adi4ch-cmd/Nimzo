import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'recharge_repository.dart';

class RechargeScreen extends ConsumerWidget {
  const RechargeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Recharge')),
        body: ref.watch(packagesProvider).when(
          loading: () => const ShimmerView(),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(packagesProvider)),
          data: (l) => l.isEmpty ? const EmptyView(title: 'No packages available') : ListView(children: [
            for (final p in l) ListTile(
              title: Text('${p['coins']} coins'),
              trailing: Text('\$${(p['usd_cents'] / 100).toStringAsFixed(2)}'),
              // TODO: start Google Play / App Store purchase with p['product_id'], then
              // call RechargeRepository.verify(...) with the receipt. Server credits coins.
              onTap: () {},
            ),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/nimzo_button.dart';
import 'vip_repository.dart';

class VipScreen extends ConsumerWidget {
  const VipScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    return Scaffold(
      appBar: AppBar(title: const Text('VIP & SVIP')),
      body: ref.watch(vipStatusProvider).when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(vipStatusProvider)),
        data: (s) => ListView(padding: const EdgeInsets.all(16), children: [
          Text('VIP level: ${s['vip_level']}', style: Theme.of(context).textTheme.titleMedium),
          Text('SVIP level: ${s['svip_level']}'),
          const SizedBox(height: 16),
          NimzoButton(label: 'Claim daily VIP reward', onPressed: () async {
            try { await ref.read(vipRepositoryProvider).claimDaily(); msg('Reward claimed'); ref.invalidate(vipStatusProvider); }
            catch (e) { msg('$e'); }
          }),
          const SizedBox(height: 12),
          NimzoButton(label: 'Claim SVIP Friday reward', outlined: true, onPressed: () async {
            try { await ref.read(vipRepositoryProvider).claimSvipFriday(); msg('Reward claimed'); ref.invalidate(vipStatusProvider); }
            catch (e) { msg('$e'); }
          }),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';

final giftHistoryProvider = FutureProvider((ref) async {
  final db = ref.watch(supabaseProvider);
  return await db.from('gift_events').select().order('created_at', ascending: false).limit(100);
});

class GiftHistoryScreen extends ConsumerWidget {
  const GiftHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gift history')),
      body: ref.watch(giftHistoryProvider).when(
        loading: () => const ShimmerView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(giftHistoryProvider)),
        data: (l) => l.isEmpty ? const EmptyView(title: 'No gifts yet') : ListView(children: [
          for (final g in l) ListTile(
            leading: Icon(g['sender_id'] == me ? Icons.north_east : Icons.south_west),
            title: Text(g['sender_id'] == me ? 'Sent ${g['total_coins']} coins' : 'Received ${(g['total_coins'] * 45) ~/ 100} diamonds'),
            trailing: Text(timeAgo(DateTime.parse(g['created_at']))),
          ),
        ]),
      ),
    );
  }
}

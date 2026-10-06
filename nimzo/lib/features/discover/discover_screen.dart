import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';
import 'leaderboard_repository.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _S();
}

class _S extends ConsumerState<DiscoverScreen> {
  String period = 'weekly';
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(supabaseProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Discover'), actions: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'weekly', label: Text('Weekly')), ButtonSegment(value: 'monthly', label: Text('Monthly'))],
            selected: {period}, onSelectionChanged: (s) => setState(() => period = s.first)),
          const SizedBox(width: 8),
        ], bottom: const TabBar(tabs: [Tab(text: 'Charm'), Tab(text: 'Wealth'), Tab(text: 'Room')])),
        body: Column(children: [
          Expanded(flex: 3, child: TabBarView(children: [for (final k in ['charm', 'wealth', 'room']) _Board(kind: k, period: period)])),
          Expanded(flex: 2, child: ref.watch(bannersProvider).when(
            loading: () => const ShimmerView(rows: 2),
            error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(bannersProvider)),
            data: (b) => b.isEmpty ? const EmptyView(title: 'No activities right now') : ListView(children: [
              for (final x in b) ListTile(
                leading: storageUrl(db, 'banners', x['image_path']) == null ? null : Image.network(storageUrl(db, 'banners', x['image_path'])!, width: 56, fit: BoxFit.cover),
                title: Text(x['title'] ?? ''), subtitle: Text(x['subtitle'] ?? '')),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  final String kind, period;
  const _Board({required this.kind, required this.period});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(leaderboardProvider((kind, period))).when(
        loading: () => const ShimmerView(rows: 5),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(leaderboardProvider((kind, period)))),
        data: (l) => l.isEmpty ? const EmptyView(title: 'No ranking yet') : ListView(children: [
          for (var i = 0; i < l.length; i++) ListTile(leading: Text('${i + 1}'), title: Text(l[i]['name'] ?? ''), trailing: Text('${l[i]['score']}')),
        ]),
      );
}

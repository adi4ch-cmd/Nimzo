import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/shimmer_view.dart';

final gamesCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.read(supabaseProvider).from('game_catalog').select().eq('active', true).order('name');
  return List<Map<String, dynamic>>.from(rows);
});

class GamesCatalogScreen extends ConsumerWidget {
  const GamesCatalogScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(title: const Text('Games'), bottom: const TabBar(tabs: [
        Tab(text: 'Featured'), Tab(text: 'Popular'), Tab(text: 'New'), Tab(text: 'All Games')
      ])),
      body: ref.watch(gamesCatalogProvider).when(
        loading: () => const ShimmerView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(gamesCatalogProvider)),
        data: (games) => games.isEmpty ? const EmptyView(title: 'No games available') : TabBarView(
          children: List.generate(4, (_) => ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: games.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final g = games[i];
              return Card(child: ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: Text(g['name']?.toString() ?? g['slug'].toString()),
                subtitle: Text('Server-settled • v${g['version'] ?? 1}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/games-play'),
              ));
            },
          )),
        ),
      ),
    ),
  );
}

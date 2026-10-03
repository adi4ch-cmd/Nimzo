import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/colors.dart';
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
              return Material(
                color: NimzoColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(g['name']?.toString() ?? g['slug'].toString()),
                      content: const Text('Games can be played inside a voice room. Open a room first, then launch the game from the room.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(color: NimzoColors.primaryFaint, borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.sports_esports_rounded, size: 30, color: NimzoColors.primaryDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g['name']?.toString() ?? g['slug'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Server-settled', style: Theme.of(context).textTheme.bodySmall),
                      ])),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                ),
              );
            },
          )),
        ),
      ),
    ),
  );
}

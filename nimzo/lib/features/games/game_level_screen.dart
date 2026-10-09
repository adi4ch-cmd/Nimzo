import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_theme.dart';

/// Progress uses only server-confirmed settled rounds, never local game taps.
final gameLevelProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final result = await ref
      .watch(sessionSupabaseProvider)
      .client
      .rpc('nimzo_game_level');
  if (result is! Map) throw StateError('Verified game level unavailable');
  return Map<String, dynamic>.from(result);
});

class GameLevelScreen extends ConsumerWidget {
  const GameLevelScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('NIMZO Game Level')),
    body: ref
        .watch(gameLevelProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Game level cannot be verified right now.'),
                TextButton(
                  onPressed: () => ref.invalidate(gameLevelProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) {
            final level = ((data['level'] as num?)?.toInt() ?? 0).clamp(0, 15);
            final played = ((data['rounds_played'] as num?)?.toInt() ?? 0);
            final next = (data['next_rounds'] as num?)?.toInt();
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/hilo/game_levels/level_$level.webp',
                        width: 116,
                        height: 116,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Game Level $level',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$played verified rounds played',
                        style: const TextStyle(color: NimzoStyle.muted),
                      ),
                      if (next != null) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (played / next).clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${next - played} more settled rounds to next level',
                        ),
                      ] else
                        const Text('Highest game level reached'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'GAME LEVEL MEDALS',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .84,
                  ),
                  itemCount: 16,
                  itemBuilder: (context, i) => Semantics(
                    label:
                        'Game level $i ${i <= level ? 'unlocked' : 'locked'}',
                    child: Column(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: i <= level ? 1 : .35,
                            child: Image.asset(
                              'assets/hilo/game_levels/level_$i.webp',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Text(
                          'LV $i',
                          style: TextStyle(
                            fontSize: 11,
                            color: i <= level
                                ? NimzoStyle.primary
                                : NimzoStyle.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Only completed game rounds with verified won/lost results count. '
                  'Pending bets, refunded games and cancelled rounds earn no progress.',
                  style: TextStyle(color: NimzoStyle.muted, fontSize: 12),
                ),
              ],
            );
          },
        ),
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';

/// Activation of known games is server-owned. Config never grants a game
/// implementation or client-side payout rights. Unknown slugs are ignored by
/// the existing APK until an actual game engine has been shipped.
final nimzoLiveGameFlagsProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return const {};
  final rows = await session.client
      .from('game_catalog')
      .select('slug,active')
      .limit(100);
  return {
    for (final row in rows)
      if (row['slug'] is String && row['active'] is bool)
        row['slug'] as String: row['active'] as bool,
  };
});

bool isKnownGameEnabled(String slug, Map<String, bool> flags) =>
    flags[slug] != false;

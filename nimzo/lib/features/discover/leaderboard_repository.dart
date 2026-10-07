import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

class LeaderboardRepository {
  final SupabaseClient _db;
  LeaderboardRepository(this._db);

  /// kind: charm | wealth | room. period: weekly | monthly. limit: 3 / 10 / 100.
  Future<List<Map<String, dynamic>>> top(
    String kind,
    String period, {
    int limit = 10,
  }) async =>
      List<Map<String, dynamic>>.from(
        await _db.rpc(
          'leaderboard',
          params: {'p_kind': kind, 'p_period': period, 'p_limit': limit},
        ),
      );
  Future<Map<String, dynamic>?> weeklyStar() async =>
      await _db.rpc('weekly_star');
  Future<List<Map<String, dynamic>>> banners() async => await _db
      .from('banners')
      .select()
      .eq('active', true)
      .lte('start_at', DateTime.now().toIso8601String())
      .gte('end_at', DateTime.now().toIso8601String())
      .order('sort_order')
      .limit(12);
}

final leaderboardRepositoryProvider = Provider(
  (ref) => LeaderboardRepository(ref.watch(sessionSupabaseProvider).client),
);
final bannersProvider = FutureProvider(
  (ref) => ref.watch(leaderboardRepositoryProvider).banners(),
);
final leaderboardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, (String, String)>(
  (ref, k) => ref.watch(leaderboardRepositoryProvider).top(k.$1, k.$2),
);

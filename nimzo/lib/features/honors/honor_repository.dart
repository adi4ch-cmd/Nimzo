import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import 'honor_milestone.dart';

class HonorRepository {
  final SupabaseClient _db;
  HonorRepository(this._db);

  Future<List<HonorMilestone>> mine() async {
    final rows = await _db.rpc('my_honor_milestones') as List;
    return rows
        .map((row) => HonorMilestone.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}

final honorRepositoryProvider = Provider(
  (ref) => HonorRepository(ref.watch(sessionSupabaseProvider).client),
);

final honorMilestonesProvider =
    FutureProvider.autoDispose<List<HonorMilestone>>(
  (ref) async {
    if (ref.watch(currentUserIdProvider) == null) {
      throw StateError('Sign in to view your honors.');
    }
    return ref.watch(honorRepositoryProvider).mine();
  },
);

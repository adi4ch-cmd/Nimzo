import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import 'vip_progress.dart';

/// Levels, expiry and rewards are all decided in Postgres. The app only reads and requests claims.
class VipRepository {
  final SupabaseClient _db;
  VipRepository(this._db);
  Future<Map<String, dynamic>> status() async {
    final result = await _db.rpc('vip_status');
    if (result is! Map) throw StateError('Membership account is unavailable');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<int, int>> svipThresholds() async {
    final rows = await _db
        .from('svip_thresholds')
        .select('level,usd_cents')
        .order('level');
    final thresholds = <int, int>{};
    for (final row in rows) {
      final level = row['level'], cents = row['usd_cents'];
      if (level is! int ||
          level < 1 ||
          cents is! int ||
          cents <= 0 ||
          thresholds.containsKey(level)) {
        throw StateError('Invalid backend SVIP catalog');
      }
      thresholds[level] = cents;
    }
    return thresholds;
  }

  /// Server-authoritative VIP purchase. Never grant levels or coins locally.
  Future<Map<String, dynamic>> purchaseNormalVip({
    required int tier,
    required String key,
  }) async {
    if (tier < 1 || tier > 10 || key.trim().length < 8) {
      throw ArgumentError('Invalid membership purchase');
    }
    final result = await _db.rpc(
      'purchase_normal_vip',
      params: {'p_tier': tier, 'p_key': key},
    );
    if (result is! Map) {
      throw StateError('VIP purchase response unavailable');
    }
    final payload = Map<String, dynamic>.from(result);
    if (payload['status'] != 'ok' && payload['status'] != 'replayed') {
      throw StateError('VIP purchase was not confirmed');
    }
    return payload;
  }

  Future<void> claimDaily() => _db.rpc('claim_vip_daily');
  Future<void> claimSvipFriday() => _db.rpc('claim_svip_friday');
  Future<List<Map<String, dynamic>>> vipDailyRewards() async {
    final rows = await _db.from('vip_daily_rewards').select().order('level');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> svipFridayRewards() async {
    final rows = await _db.from('svip_friday_rewards').select().order('level');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

final vipRepositoryProvider = Provider(
  (ref) => VipRepository(ref.watch(sessionSupabaseProvider).client),
);
final vipStatusProvider = FutureProvider(
  (ref) => ref.watch(vipRepositoryProvider).status(),
);
final svipThresholdsProvider = FutureProvider(
  (ref) => ref.watch(vipRepositoryProvider).svipThresholds(),
);
final svipProgressProvider = FutureProvider<SvipProgress>((ref) async {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) throw StateError('Sign in required');
  final statusFuture = ref.watch(vipStatusProvider.future);
  final thresholdsFuture = ref.watch(svipThresholdsProvider.future);
  // Subscribe to both errors immediately, including account changes/disposal.
  final (status, thresholds) = await (statusFuture, thresholdsFuture).wait;
  // Old deployments lack cycle status: never treat stale profile counters as current.
  final cents = status['svip_cycle_cents'];
  if (cents is! int ||
      cents < 0 ||
      status['svip_cycle_active'] is! bool ||
      thresholds.isEmpty) throw StateError('Recharge progress unavailable');
  return SvipProgress(cycleCents: cents, thresholds: thresholds);
});

final vipDailyRewardsProvider = FutureProvider(
  (ref) => ref.watch(vipRepositoryProvider).vipDailyRewards(),
);
final svipFridayRewardsProvider = FutureProvider(
  (ref) => ref.watch(vipRepositoryProvider).svipFridayRewards(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/supabase_provider.dart';

/// Levels, expiry and rewards are all decided in Postgres. The app only reads and requests claims.
class VipRepository {
  final SupabaseClient _db;
  VipRepository(this._db);
  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(await _db.rpc('vip_status'));
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
final vipRepositoryProvider = Provider((ref) => VipRepository(ref.watch(supabaseProvider)));
final vipStatusProvider = FutureProvider((ref) => ref.watch(vipRepositoryProvider).status());

final vipDailyRewardsProvider = FutureProvider((ref) => ref.watch(vipRepositoryProvider).vipDailyRewards());
final svipFridayRewardsProvider = FutureProvider((ref) => ref.watch(vipRepositoryProvider).svipFridayRewards());

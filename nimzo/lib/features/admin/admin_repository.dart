import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/supabase_provider.dart';

/// Every method is authorised by Postgres (`is_admin()`), not by this class.
/// The full dashboard should be a separate web app using the same RPCs.
class AdminRepository {
  final SupabaseClient _db;
  AdminRepository(this._db);
  Future<void> setStatus(String userId, String status) => _db.rpc('admin_set_status', params: {'p_user': userId, 'p_status': status});
  Future<List<Map<String, dynamic>>> reports() async => List<Map<String, dynamic>>.from(await _db.rpc('admin_reports'));
}
final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(supabaseProvider)));

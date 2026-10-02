import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/supabase_provider.dart';

/// Packages/prices come from the backend. Purchases are verified by the
/// `verify-purchase` Edge Function against Google Play / App Store using
/// server-held credentials. The client never sends a trusted price.
class RechargeRepository {
  final SupabaseClient _db;
  RechargeRepository(this._db);
  Future<List<Map<String, dynamic>>> packages() async => await _db.from('recharge_packages').select().eq('active', true).order('usd_cents');
  Future<void> verify({required String store, required String productId, required String receipt}) async {
    await _db.functions.invoke('verify-purchase', body: {'store': store, 'product_id': productId, 'receipt': receipt});
  }
}
final rechargeRepositoryProvider = Provider((ref) => RechargeRepository(ref.watch(supabaseProvider)));
final packagesProvider = FutureProvider((ref) => ref.watch(rechargeRepositoryProvider).packages());

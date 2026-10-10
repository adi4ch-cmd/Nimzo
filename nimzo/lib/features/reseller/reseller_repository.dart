import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/error_handler.dart';
import '../../core/providers/supabase_provider.dart';

class ResellerRepository {
  final SupabaseClient _db;
  ResellerRepository(this._db);
  Future<Map<String, dynamic>?> verifyUser(int nimzoId) async {
    final r = await _db
        .from('profiles')
        .select('id,display_name,nimzo_id')
        .eq('nimzo_id', nimzoId)
        .maybeSingle();
    return r;
  }

  Future<void> recharge(String userId, int coins, String key) async {
    try {
      await _db.rpc(
        'reseller_recharge',
        params: {'p_user': userId, 'p_coins': coins, 'p_key': key},
      );
    } catch (e) {
      throw mapError(e);
    }
  }
}

final resellerRepositoryProvider = Provider(
  (ref) => ResellerRepository(ref.watch(sessionSupabaseProvider).client),
);

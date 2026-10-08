import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';

bool confirmedPurchase(dynamic data,
        {required String store,
        required String productId,
        required String transactionId}) =>
    data is Map &&
    data['ok'] == true &&
    ['credited', 'replayed'].contains(data['status']) &&
    data['store'] == store &&
    data['product_id'] == productId &&
    data['transaction_id'] == transactionId &&
    data['coins'] is int &&
    (data['coins'] as int) > 0 &&
    data['environment'] == 'production';

/// Packages/prices come from the backend. Purchases are verified by the
/// `verify-purchase` Edge Function against Google Play / App Store using
/// server-held credentials. The client never sends a trusted price.
class RechargeRepository {
  final SupabaseClient _db;
  RechargeRepository(this._db);
  Future<List<Map<String, dynamic>>> packages() async => await _db
      .from('recharge_packages')
      .select()
      .eq('active', true)
      .order('usd_cents');
  Future<void> verify({
    required String store,
    required String productId,
    required String receipt,
    String? transactionId,
  }) async {
    final canonicalStore = store == 'google'
        ? 'google_play'
        : store == 'apple'
            ? 'app_store'
            : store;
    final response = await _db.functions.invoke(
      'verify-purchase',
      body: {
        'store': canonicalStore,
        'product_id': productId,
        'receipt': receipt,
        if (transactionId != null) 'transaction_id': transactionId,
      },
    );
    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        !confirmedPurchase(data,
            store: canonicalStore,
            productId: productId,
            transactionId: canonicalStore == 'google_play'
                ? receipt
                : transactionId ?? '')) {
      throw StateError(
        data is Map
            ? (data['error']?.toString() ??
                'Purchase settlement was not confirmed')
            : 'Invalid purchase verification response',
      );
    }
  }
}

final rechargeRepositoryProvider = Provider(
  (ref) => RechargeRepository(ref.watch(sessionSupabaseProvider).client),
);
final packagesProvider = FutureProvider(
  (ref) => ref.watch(rechargeRepositoryProvider).packages(),
);

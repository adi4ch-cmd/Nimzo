import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authoritative Store purchase. Never update a wallet locally.
class NimzoStorePurchaseRepository {
  const NimzoStorePurchaseRepository(this.db);
  final SupabaseClient db;

  Future<StorePurchaseResult> purchase({
    required String itemId,
    required int expectedPrice,
    required String retryKey,
  }) async {
    if (itemId.length < 5 || itemId.length > 100 ||
        expectedPrice < 1 || expectedPrice > 1000000000000 ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(retryKey)) {
      throw ArgumentError('Invalid Store request');
    }
    final response = await db.rpc('nimzo_store_purchase', params: {
      'p_item_id': itemId,
      'p_expected_price': expectedPrice,
      'p_key': retryKey,
    });
    if (response is! Map) {
      throw StateError('Unrecognized Store server response');
    }
    final result = Map<String, dynamic>.from(response);
    final status = result['status'];
    final total = result['total'];
    if (result['item_id'] != itemId ||
        !const {'purchased', 'replayed', 'already_owned'}.contains(status) ||
        total is! num ||
        (status == 'already_owned' ? total.toInt() != 0
          : total.toInt() != expectedPrice)) {
      throw StateError('Store purchase was not verified by server');
    }
    return StorePurchaseResult(status: status as String, total: total.toInt());
  }
}

class StorePurchaseResult {
  const StorePurchaseResult({required this.status, required this.total});
  final String status;
  final int total;
  bool get charged => status == 'purchased';
}

import '../../core/services/renderable_media.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/services/approved_media_bytes.dart';
import '../../core/services/media_publication.dart';

final nimzoStorePurchaseRepositoryProvider =
    Provider<NimzoStorePurchaseRepository>((ref) =>
        NimzoStorePurchaseRepository(
            ref.watch(sessionSupabaseProvider).client));

/// Server-authoritative Store purchase. Never update a wallet locally.
class NimzoStorePurchaseRepository {
  const NimzoStorePurchaseRepository(this.db, {this.verifyBytes});
  final SupabaseClient db;
  final Future<void> Function(String, ApprovedMediaPublication)? verifyBytes;

  Future<StorePurchaseResult> purchase({
    required String itemId,
    required int expectedPrice,
    required String retryKey,
  }) async {
    if (itemId.length < 5 ||
        itemId.length > 100 ||
        expectedPrice < 1 ||
        expectedPrice > 1000000000000 ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(retryKey)) {
      throw ArgumentError('Invalid Store request');
    }
    final account = db.auth.currentUser?.id;
    void ensureAccount() { if(db.auth.currentUser?.id != account) throw StateError('Account changed. Reopen the Store.'); }
    final params = {
      'p_item_id': itemId,
      'p_expected_price': expectedPrice,
      'p_key': retryKey
    };
    // A completed charge remains recoverable even after an object is removed,
    // deactivated or its CDN is unavailable. This read can never charge coins.
    final receipt = await db.rpc('store_purchase_receipt', params: params);
    ensureAccount();
    if (receipt != null) {
      final result = _parse(receipt, itemId, expectedPrice);
      if (result.status == 'purchased') {
        throw StateError('Receipt lookup attempted to report a new purchase');
      }
      return result;
    }
    final rows = await db
        .from('nimzo_cosmetic_media')
        .select()
        .eq('item_id', itemId)
        .eq('approved', true)
        .limit(1);
    if (rows.length != 1)
      throw StateError('Item media unavailable. No coins charged.');
    final media = rows.single;
    final url = media['asset_url'];
    final kind = media['media_kind'];
    if (url is! String ||
        kind is! String ||
        !const {'image', 'svga', 'vap'}.contains(kind) ||
        media['rights_reference'] is! String ||
        (media['rights_reference'] as String).trim().isEmpty ||
        DateTime.tryParse(media['verified_at']?.toString() ?? '') == null ||
        DateTime.tryParse(media['device_verified_at']?.toString() ?? '') ==
            null) {
      throw StateError('Item publication unverified. No coins charged.');
    }
    final publication = parseMediaPublication(media, kind: kind);
    if (publication == null ||
        !ApprovedMediaBytes.isSafeUrl(url) ||
        !Uri.parse(url).path.contains(publication.sha256Hex)) {
      throw StateError('Item publication incomplete. No coins charged.');
    }
    if (verifyBytes != null) {
      await verifyBytes!(url, publication);
    } else {
      final bytes =
          await ApprovedMediaBytes.fetch(url, publication: publication);
      await validateRenderableMedia(bytes, publication);
    }
    ensureAccount();
    return _parse(await db.rpc('nimzo_store_purchase', params: params), itemId,
        expectedPrice);
  }

  StorePurchaseResult _parse(
      Object? response, String itemId, int expectedPrice) {
    if (response is! Map)
      throw StateError('Unrecognized Store server response');
    final result = Map<String, dynamic>.from(response);
    final status = result['status'], total = result['total'];
    if (result['item_id'] != itemId ||
        !const {'purchased', 'replayed', 'already_owned'}.contains(status) ||
        total is! int ||
        (status == 'already_owned' ? total != 0 : total != expectedPrice)) {
      throw StateError('Store purchase was not verified by server');
    }
    final expires = result['expires_at'];
    if (expires != null &&
        (expires is! String || DateTime.tryParse(expires) == null)) {
      throw StateError('Store expiry was not verified by server');
    }
    return StorePurchaseResult(
        status: status as String,
        total: total,
        expiresAt:
            expires == null ? null : DateTime.parse(expires as String).toUtc());
  }
}

class StorePurchaseResult {
  const StorePurchaseResult(
      {required this.status, required this.total, this.expiresAt});
  final String status;
  final int total;
  final DateTime? expiresAt;
  bool get charged => status == 'purchased';
}

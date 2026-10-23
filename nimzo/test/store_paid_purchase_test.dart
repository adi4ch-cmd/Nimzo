import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/store/store_purchase_repository.dart';

const key = '0123456789abcdef0123456789abcdef';
const item = 'nimzo-paid-verified-frame';
const price = 250000;
final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
Map<String, Object> media() => {
      'item_id': item,
      'asset_url': 'https://cdn.example.com/${sha256.convert(png)}.png',
      'media_kind': 'image',
      'sha256': sha256.convert(png).toString(),
      'byte_size': png.length,
      'mime_type': 'image/png',
      'rights_reference': 'authorized-owner-source',
      'verified_at': '2026-10-21T00:00:00Z',
      'device_verified_at': '2026-10-21T00:00:00Z',
    };
http.Response jsonResponse(http.Request request, Object? value) =>
    http.Response(jsonEncode(value), 200,
        request: request, headers: {'content-type': 'application/json'});

void main() {
  test(
      'receipt read then verified bytes precede first charge; retry skips unavailable media',
      () async {
    final calls = <String>[];
    var settled = false;
    final db = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      final path = request.url.path.split('/').last;
      calls.add(path);
      if (path == 'store_purchase_receipt') {
        expect(jsonDecode(request.body),
            {'p_item_id': item, 'p_expected_price': price, 'p_key': key});
        return jsonResponse(
            request,
            settled
                ? {'status': 'replayed', 'item_id': item, 'total': price}
                : null);
      }
      if (path == 'nimzo_cosmetic_media')
        return jsonResponse(request, [media()]);
      expect(path, 'nimzo_store_purchase');
      expect(calls.lastIndexOf('verified_bytes'),
          greaterThan(calls.lastIndexOf('nimzo_cosmetic_media')));
      settled = true;
      return jsonResponse(
          request, {'status': 'purchased', 'item_id': item, 'total': price});
    }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    final repo =
        NimzoStorePurchaseRepository(db, verifyBytes: (url, publication) async {
      publication.validate(png, 'image/png');
      calls.add('verified_bytes');
    });
    expect(
        (await repo.purchase(itemId: item, expectedPrice: price, retryKey: key))
            .charged,
        isTrue);
    expect(
        (await repo.purchase(itemId: item, expectedPrice: price, retryKey: key))
            .status,
        'replayed');
    expect(calls, [
      'store_purchase_receipt',
      'nimzo_cosmetic_media',
      'verified_bytes',
      'nimzo_store_purchase',
      'store_purchase_receipt'
    ]);
  });
  test('failed media integrity never submits a charge', () async {
    final calls = <String>[];
    final db = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((r) async {
      final path = r.url.path.split('/').last;
      calls.add(path);
      return jsonResponse(
          r, path == 'store_purchase_receipt' ? null : [media()]);
    }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    final repo = NimzoStorePurchaseRepository(db,
        verifyBytes: (url, p) async =>
            p.validate(Uint8List.fromList([1, 2]), 'image/png'));
    await expectLater(
        repo.purchase(itemId: item, expectedPrice: price, retryKey: key),
        throwsFormatException);
    expect(calls, ['store_purchase_receipt', 'nimzo_cosmetic_media']);
  });
  test('incomplete approval cannot submit checkout', () async {
    var charges = 0;
    final db = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/store_purchase_receipt'))
        return jsonResponse(r, null);
      if (r.url.path.endsWith('/nimzo_store_purchase')) charges++;
      return jsonResponse(r, [
        {...media()}..remove('device_verified_at')
      ]);
    }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    await expectLater(
        NimzoStorePurchaseRepository(db)
            .purchase(itemId: item, expectedPrice: price, retryKey: key),
        throwsStateError);
    expect(charges, 0);
  });
  test('invalid request never reaches network', () async {
    var calls = 0;
    final db = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((r) async {
      calls++;
      return jsonResponse(r, null);
    }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    final repo = NimzoStorePurchaseRepository(db);
    await expectLater(
        repo.purchase(itemId: item, expectedPrice: 0, retryKey: key),
        throwsArgumentError);
    await expectLater(
        repo.purchase(itemId: item, expectedPrice: 100, retryKey: 'bad'),
        throwsArgumentError);
    expect(calls, 0);
  });
  test('receipt must match item, integer price and non-charge replay status',
      () async {
    for (final receipt in [
      {'status': 'replayed', 'item_id': 'other-item', 'total': price},
      {'status': 'replayed', 'item_id': item, 'total': price + 1},
      {'status': 'replayed', 'item_id': item, 'total': 250000.5},
      {'status': 'purchased', 'item_id': item, 'total': price},
      {'status': 'already_owned', 'item_id': item, 'total': 1},
    ]) {
      final db = SupabaseClient('https://example.supabase.co', 'test',
          httpClient: MockClient((r) async => jsonResponse(r, receipt)),
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      try {
        await expectLater(
            NimzoStorePurchaseRepository(db)
                .purchase(itemId: item, expectedPrice: price, retryKey: key),
            throwsStateError);
      } finally {
        await db.dispose();
      }
    }
  });
}

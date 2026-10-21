import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/store/store_purchase_repository.dart';

const key = '0123456789abcdef0123456789abcdef';

void main() {
  test('paid Store sends price + stable idempotency key to the server', () async {
    var calls = 0;
    final db = SupabaseClient('https://example.supabase.co', 'test',
      httpClient: MockClient((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/rpc/nimzo_store_purchase'));
        expect(jsonDecode(request.body), {
          'p_item_id': 'nimzo-paid-verified-frame',
          'p_expected_price': 250000,
          'p_key': key,
        });
        return http.Response(jsonEncode({
          'status': calls == 1 ? 'purchased' : 'replayed',
          'item_id': 'nimzo-paid-verified-frame',
          'total': 250000,
        }), 200, request: request,
          headers: {'content-type':'application/json'});
      }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    final repository = NimzoStorePurchaseRepository(db);
    final first = await repository.purchase(
      itemId: 'nimzo-paid-verified-frame',
      expectedPrice: 250000, retryKey: key);
    expect(first.charged, isTrue);
    expect(first.total, 250000);
    final retry = await repository.purchase(
      itemId: 'nimzo-paid-verified-frame',
      expectedPrice: 250000, retryKey: key);
    expect(retry.status, 'replayed');
    expect(retry.charged, isFalse);
    expect(calls, 2);
  });

  test('invalid keys or zero prices never reach remote checkout', () async {
    var called = false;
    final db = SupabaseClient('https://example.supabase.co', 'test',
      httpClient: MockClient((request) async {
        called = true;
        return http.Response('{}',200,request:request,
          headers:{'content-type':'application/json'});
      }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    final repository = NimzoStorePurchaseRepository(db);
    await expectLater(repository.purchase(
      itemId: 'nimzo-paid-frame', expectedPrice: 0, retryKey:key),
      throwsArgumentError);
    await expectLater(repository.purchase(
      itemId: 'nimzo-paid-frame', expectedPrice: 100, retryKey:'predictable'),
      throwsArgumentError);
    expect(called, isFalse);
  });

  test('unverified RPC statuses and price mismatches are rejected', () async {
    final db = SupabaseClient('https://example.supabase.co', 'test',
      httpClient: MockClient((request) async => http.Response(
        jsonEncode({'status':'purchased','item_id':'other-item','total':5}),
        200,request:request,headers:{'content-type':'application/json'})),
      authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(db.dispose);
    await expectLater(NimzoStorePurchaseRepository(db).purchase(
      itemId:'nimzo-paid-frame',expectedPrice:100,retryKey:key),
      throwsStateError);
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/moments/moment_repository.dart';

void main() {
  test(
      'moment gifts forward recipient quantity and stable key to settlement RPC',
      () async {
    var calls = 0;
    final db = SupabaseClient('https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
      calls++;
      expect(r.url.path, '/rest/v1/rpc/send_moment_gift');
      expect(jsonDecode(r.body), {
        'p_moment': 'moment',
        'p_receiver': 'author',
        'p_gift': 'gift',
        'p_qty': 10,
        'p_key': 'stable-key',
      });
      return http.Response('{"status":"sent"}', 200,
          headers: {'content-type': 'application/json'}, request: r);
    }));
    addTearDown(db.dispose);
    await MomentRepository(db).sendGift(
        momentId: 'moment',
        receiverId: 'author',
        giftId: 'gift',
        qty: 10,
        key: 'stable-key');
    expect(calls, 1);
  });
}

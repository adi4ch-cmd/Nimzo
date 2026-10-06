import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';

Future<SupabaseClient> signedClient(http.Response Function(http.Request) response) async {
  final db = SupabaseClient('https://example.supabase.co', 'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final result = response(request);
      return http.Response(result.body, result.statusCode, request: request,
        headers: {'content-type': 'application/json'});
    }));
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  String encode(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  await db.auth.recoverSession(jsonEncode({
    'access_token': '${encode({'alg':'HS256','typ':'JWT'})}.${encode({'sub':'me','exp':exp})}.test-signature',
    'refresh_token': 'test-refresh', 'token_type': 'bearer', 'expires_at': exp,
    'user': {'id':'me','aud':'authenticated','created_at':'2026-10-06T00:00:00Z'},
  }));
  addTearDown(db.dispose);
  return db;
}

void main() {
  test('profile edit sends only editable fields and verifies persisted row', () async {
    final db = await signedClient((request) {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.me');
      expect(jsonDecode(request.body), {'display_name': 'Amina','bio': 'Hello'});
      return http.Response('{"id":"me"}', 200);
    });
    await ProfileRepository(db).update(displayName: ' Amina ', bio: 'Hello');
  });
  test('zero affected rows must not report a successful save', () async {
    final db = await signedClient((_) => http.Response('{"code":"PGRST116","message":"JSON object requested","details":"Results contain 0 rows"}', 406));
    await expectLater(ProfileRepository(db).update(bio: 'Hello'), throwsA(isA<Exception>()));
  });
  test('profile gift forwards recipient and stable key without room or client price', () async {
    final db = await signedClient((request) {
      expect(request.url.path, '/rest/v1/rpc/send_profile_gift');
      expect(jsonDecode(request.body), {'p_receiver':'other','p_gift':'gift','p_qty':2,'p_key':'stable-key'});
      return http.Response('{"status":"ok"}', 200);
    });
    await GiftRepository(db).sendProfile(receiverId: 'other', giftId: 'gift', qty: 2, key: 'stable-key');
  });
}

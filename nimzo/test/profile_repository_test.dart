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
  test('profile search matches username and display name without .or() filters', () async {
    final queried = <String>[];
    final db = await signedClient((request) {
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/profiles');
      expect(request.url.queryParameters.containsKey('or'), isFalse);
      expect(request.url.queryParameters['limit'], '20');
      final column = request.url.queryParameters.containsKey('username')
          ? 'username'
          : 'display_name';
      queried.add(column);
      expect(request.url.queryParameters[column], 'ilike.%Amina%');
      return http.Response('[]', 200);
    });
    expect(await ProfileRepository(db).search(' Amina '), isEmpty);
    expect(queried, ['username', 'display_name']);
  });

  test('profile search treats percent and underscore as literal characters', () async {
    final queried = <String>[];
    final db = await signedClient((request) {
      final column = request.url.queryParameters.containsKey('username')
          ? 'username'
          : 'display_name';
      queried.add(column);
      expect(request.url.queryParameters[column], r'ilike.%A\%B\_C%');
      expect(request.url.queryParameters.containsKey('or'), isFalse);
      return http.Response('[]', 200);
    });
    expect(await ProfileRepository(db).search('A%B_C'), isEmpty);
    expect(queried, ['username', 'display_name']);
  });

  test('numeric profile search uses permanent Nimzo ID', () async {
    final db = await signedClient((request) {
      expect(request.url.queryParameters['nimzo_id'], 'eq.100005');
      expect(request.url.queryParameters.containsKey('or'), isFalse);
      return http.Response('[]', 200);
    });
    expect(await ProfileRepository(db).search('100005'), isEmpty);
  });

  test('blank profile search does not query the server', () async {
    final db = await signedClient((_) {
      fail('Empty searches should not reach Supabase');
    });
    expect(await ProfileRepository(db).search('   '), isEmpty);
  });

  test('invalid gift quantity never calls Supabase', () async {
    final db = await signedClient((_) {
      fail('Invalid gift quantity must never reach the database');
    });
    final repo = GiftRepository(db);
    await expectLater(
      repo.sendProfile(receiverId: 'other', giftId: 'gift', qty: 0, key: 'key'),
      throwsArgumentError,
    );
    await expectLater(
      repo.send(roomId: 'room', receiverId: 'other', giftId: 'gift',
          qty: -1, key: 'key'),
      throwsArgumentError,
    );
  });

  test('gift requests require recipient, gift, room and stable key', () async {
    final db = await signedClient((_) {
      fail('Invalid gift request must never reach the database');
    });
    final repo = GiftRepository(db);
    await expectLater(
      repo.sendProfile(receiverId: '', giftId: 'gift', qty: 1, key: 'key'),
      throwsArgumentError,
    );
    await expectLater(
      repo.sendProfile(receiverId: 'other', giftId: '', qty: 1, key: 'key'),
      throwsArgumentError,
    );
    await expectLater(
      repo.sendProfile(receiverId: 'other', giftId: 'gift', qty: 1, key: ' '),
      throwsArgumentError,
    );
    await expectLater(
      repo.send(roomId: '', receiverId: 'other', giftId: 'gift',
          qty: 1, key: 'key'),
      throwsArgumentError,
    );
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

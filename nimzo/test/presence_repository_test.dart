import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nimzo/core/services/presence_service.dart';
import 'profile_repository_test.dart' show signedClient;

void main() {
  test('presence batches more than100 peers without losing indicators',
      () async {
    var requests = 0;
    final db = await signedClient((request) {
      requests++;
      final users =
          (jsonDecode(request.body)['p_users'] as List).cast<String>();
      expect(users.length, lessThanOrEqualTo(100));
      return http.Response(
          jsonEncode([
            for (final id in users) {'user_id': id, 'is_online': true}
          ]),
          200);
    });
    final result = await PresenceRepository(db)
        .statuses([for (var i = 0; i < 101; i++) 'peer-$i']);
    expect(result.length, 101);
    expect(requests, 2);
  });
  test('unknown or blocked presence is never invented as offline', () async {
    final db = await signedClient(
        (_) => http.Response('[{"user_id":"unknown","is_online":null}]', 200));
    expect(await PresenceRepository(db).statuses(['unknown']), isEmpty);
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nimzo/features/social/family_repository.dart';
import 'profile_repository_test.dart' show signedClient;

void main() {
  test('old owned and joined families stay visible outside newest directory',
      () async {
    Map<String, dynamic> family(String id, String owner) => {
          'id': id,
          'owner_id': owner,
          'name': id,
          'description': '',
          'nimzo_family_members': <Map<String, dynamic>>[],
        };
    final db = await signedClient((request) {
      final query = request.url.queryParameters;
      final rows = request.url.path.endsWith('nimzo_family_members')
          ? [
              {'nimzo_families': family('old-joined', 'other')}
            ]
          : query['owner_id'] == 'eq.me'
              ? [family('old-owned', 'me')]
              : [for (var i = 0; i < 100; i++) family('new-$i', 'other')];
      return http.Response(jsonEncode(rows), 200);
    });
    final families = await FamilyRepository(db).directory();
    expect(families.length, 102);
    expect(families.take(2).map((f) => f.id), ['old-owned', 'old-joined']);
  });
  test('creation rejects an unverified backend response', () async {
    final db =
        await signedClient((_) => http.Response('{"created":false}', 200));
    await expectLater(
        FamilyRepository(db).create('Family', 'hello', 'same_request_key'),
        throwsStateError);
  });
}

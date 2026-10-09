import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nimzo/features/moments/moment_repository.dart';
import 'profile_repository_test.dart' show signedClient;

void main() {
  test('Moment update rejects zero affected rows', () async {
    final db = await signedClient((request) {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['author_id'], 'eq.me');
      return http.Response('', 204);
    });
    await expectLater(MomentRepository(db).update('post', text: 'Draft'),
        throwsA(isA<Exception>()));
  });
  test('Moment update confirms saved row owned by authenticated author',
      () async {
    final db = await signedClient((request) {
      expect(request.url.queryParameters['id'], 'eq.post');
      expect(request.url.queryParameters['author_id'], 'eq.me');
      expect(request.url.queryParameters['select'], 'id');
      return http.Response('{"id":"post"}', 200);
    });
    await MomentRepository(db).update('post', text: 'Draft');
  });
}

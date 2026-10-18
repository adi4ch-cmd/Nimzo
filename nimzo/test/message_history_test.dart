import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nimzo/features/messages/message_repository.dart';
import 'profile_repository_test.dart' show signedClient;

void main() {
  test('latest page uses chronological order with an ID tie breaker', () async {
    final db = await signedClient((request) {
      expect(request.url.queryParameters['conversation_key'], 'eq.me:other');
      expect(request.url.queryParameters['order'],
          'created_at.desc.nullslast,id.desc.nullslast');
      expect(request.url.queryParameters['limit'], '50');
      return http.Response('[]', 200);
    });
    expect(await MessageRepository(db).recent('other'), isEmpty);
  });
  test('older messages query the exact conversation and stable cursor',
      () async {
    final db = await signedClient((request) {
      expect(request.url.queryParameters['conversation_key'], 'eq.me:other');
      expect(request.url.queryParameters['limit'], '50');
      expect(request.url.queryParameters['or'], contains('id.lt.cursor'));
      return http.Response(
          jsonEncode([
            {
              'id': 'old',
              'sender_id': 'me',
              'receiver_id': 'other',
              'body': 'older',
              'created_at': '2026-10-17T00:00:00Z',
            }
          ]),
          200);
    });
    final cursor = Message(
        id: 'cursor',
        senderId: 'me',
        receiverId: 'other',
        kind: 'text',
        read: true,
        createdAt: DateTime.utc(2026, 10, 18));
    final rows = await MessageRepository(db).older('other', before: cursor);
    expect(rows.single.body, 'older');
  });
  test('shifting live window retains its previous boundary message', () {
    Message row(int i) => Message(
        id: '$i',
        senderId: 'me',
        receiverId: 'other',
        kind: 'text',
        read: true,
        createdAt: DateTime.utc(2026, 10, 18).add(Duration(seconds: i)));
    final result = reconcileMessageWindow(
        [for (var i = 1; i <= 100; i++) row(i)],
        [for (var i = 52; i <= 101; i++) row(i)],
        previousPageIds: {for (var i = 51; i <= 100; i++) '$i'});
    expect(result.rows.length, 101);
    expect(result.rows.any((m) => m.id == '51'), isTrue);
    expect(result.reset, isFalse);
  });
  test(
      'non-overlapping reconnect window resets pagination instead of keeping a gap',
      () {
    Message row(int i) => Message(
        id: '$i',
        senderId: 'me',
        receiverId: 'other',
        kind: 'text',
        read: true,
        createdAt: DateTime.utc(2026, 10, 18).add(Duration(seconds: i)));
    final result = reconcileMessageWindow(
        [for (var i = 1; i <= 100; i++) row(i)],
        [for (var i = 151; i <= 200; i++) row(i)],
        previousPageIds: {for (var i = 51; i <= 100; i++) '$i'});
    expect(result.rows.first.id, '151');
    expect(result.reset, isTrue);
  });
  test(
      'message merge deduplicates live overlap and retains chronological order',
      () {
    Message message(String id, int second) => Message(
        id: id,
        senderId: 'me',
        receiverId: 'other',
        kind: 'text',
        read: false,
        createdAt: DateTime.utc(2026, 10, 18, 0, 0, second));
    expect(
        mergeMessageHistory([message('one', 1), message('two', 2)],
            [message('two', 2), message('three', 3)]).map((m) => m.id),
        ['one', 'two', 'three']);
  });
}

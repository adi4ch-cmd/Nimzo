import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';

void main() {
  const sender = '11111111-1111-4111-8111-111111111111';
  const receiver = '22222222-2222-4222-8222-222222222222';

  test('settled animation resolves genuine sender and receiver through profiles', () async {
    var requests = 0;
    final db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/profiles');
        expect(request.url.queryParameters['id'], startsWith('in.('));
        return http.Response(
          jsonEncode([
            {
              'id': sender,
              'nimzo_id': 100005,
              'display_name': 'Test Sender',
              'username': 'someone',
            },
            {
              'id': receiver,
              'nimzo_id': 100006,
              'display_name': null,
              'username': 'Test Recipient',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(db.dispose);
    final result = await GiftRepository(db).participantNamesForVerifiedEvent({
      'sender_id': sender,
      'receiver_id': receiver,
    });
    expect(result[sender], 'Test Sender');
    expect(result[receiver], 'Test Recipient');
    expect(requests, 1);
  });

  test('invalid identity is never interpolated into a profile query', () async {
    var requests = 0;
    final db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(db.dispose);
    expect(
      await GiftRepository(db).participantNamesForVerifiedEvent({
        'sender_id': 'not-a-uuid',
        'receiver_id': null,
      }),
      isEmpty,
    );
    expect(requests, 0);
  });
}

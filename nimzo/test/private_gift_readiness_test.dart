import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/private_animal_gifts.dart';

void main() {
  for (final available in [true, false]) {
    test('private readiness $available never requests media or settles coins', () async {
      final requests = <http.Request>[];
      final db = SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'ready': available}), 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      addTearDown(db.dispose);
      final repository = GiftRepository(db);
      expect(await repository.privateMediaReady(holyTigerGiftId), available);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/functions/v1/gift-media');
      expect(jsonDecode(requests.single.body),
          {'gift_id': holyTigerGiftId, 'kind': 'ready'});
      expect(await repository.privateMediaReady('unknown'), false);
      expect(requests, hasLength(1));
    });
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';

void main() {
  for (final giftId in [
    'e1e65664-37f8-4cfd-9640-3bb035723b98',
    'c3f41e6e-68d5-4e56-9253-33421ec18fc3',
  ]) {
    test('approved media is looked up by exact catalog ID $giftId', () async {
      final db = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/gift_animation_media');
          expect(request.url.queryParameters['gift_id'], 'eq.$giftId');
          expect(request.url.queryParameters['approved'], 'eq.true');
          return http.Response(
            jsonEncode([
              {'video_url': 'https://example.com/$giftId.mp4'},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(db.dispose);
      expect(
        await GiftRepository(db).approvedAnimationUrl(giftId),
        'https://example.com/$giftId.mp4',
      );
    });
  }
  for (final rows in [
    <Map<String, Object?>>[],
    [
      {'video_url': null},
    ],
    [
      {'video_url': 'http://example.com/insecure.mp4'},
    ],
    [
      {'video_url': 'assets/gifts/unbundled.mp4'},
    ],
  ]) {
    test(
      'missing or unapproved source never invents a local video: $rows',
      () async {
        final db = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode(rows),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(db.dispose);
        expect(await GiftRepository(db).approvedAnimationUrl('gift'), isNull);
      },
    );
  }
}

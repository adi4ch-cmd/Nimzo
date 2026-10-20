import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';

void main() {
  test(
    'catalog preserves server prices and marks only approved HTTPS media',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final isMedia = request.url.path.endsWith('gift_animation_media');
          expect(
            request.url.queryParameters[isMedia ? 'approved' : 'active'],
            'eq.true',
          );
          return http.Response(
            jsonEncode(
              isMedia
                  ? [
                      {
                        'gift_id': 'approved',
                        'video_url': 'https://example.com/coffee.mp4',
                      },
                      {
                        'gift_id': 'unsafe',
                        'video_url': 'http://example.com/insecure.mp4',
                      },
                    ]
                  : [
                      {
                        'id': 'approved',
                        'name': 'Coffee',
                        'category': 'Classic',
                        'coin_price': 501,
                        'asset_path': null,
                      },
                      {
                        'id': 'unsafe',
                        'name': 'Tea',
                        'category': 'Classic',
                        'coin_price': 502,
                        'asset_path': null,
                      },
                      {
                        'id': 'static',
                        'name': 'Sports Car',
                        'category': 'Classic',
                        'coin_price': 503,
                        'asset_path': null,
                      },
                    ],
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final gifts = await GiftRepository(client).catalog();
      expect(gifts.map((gift) => gift.price), [501, 502, 503]);
      expect(gifts.map((gift) => gift.requiresAnimation), [true, false, false]);
      expect(
        gifts.last.name,
        'Sports Car',
      ); // A display name cannot grant playback.
    },
  );
}

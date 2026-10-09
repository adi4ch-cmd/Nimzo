import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/errors/app_exception.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/moments/moment_repository.dart';

void main() {
  for (final kind in ['room', 'profile', 'moment']) {
    test(
      '$kind gift explains insufficient coins without exposing RPC text',
      () async {
        final db = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (r) async => http.Response(
              jsonEncode({
                'code': 'P0001',
                'message': 'insufficient coins',
                'details': 'private database detail',
                'hint': null,
              }),
              400,
              headers: {'content-type': 'application/json'},
              request: r,
            ),
          ),
        );
        addTearDown(db.dispose);
        final gifts = GiftRepository(db);
        final request = switch (kind) {
          'room' => gifts.send(
            roomId: 'room',
            receiverId: 'receiver',
            giftId: 'gift',
            qty: 1,
            key: 'stable-key',
          ),
          'profile' => gifts.sendProfile(
            receiverId: 'receiver',
            giftId: 'gift',
            qty: 1,
            key: 'stable-key',
          ),
          _ => MomentRepository(db).sendGift(
            momentId: 'moment',
            receiverId: 'receiver',
            giftId: 'gift',
            qty: 1,
            key: 'stable-key',
          ),
        };
        await expectLater(
          request,
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              'Not enough coins. Top up your wallet and retry this gift.',
            ),
          ),
        );
      },
    );
  }
}

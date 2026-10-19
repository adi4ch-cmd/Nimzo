import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_svga_overlay.dart';
import 'package:nimzo/features/gifts/verified_gift_broadcast.dart';
import 'package:nimzo/features/gifts/private_animal_gifts.dart';
import 'package:nimzo/features/gifts/gift_celebration_overlay.dart';

final privateMediaLookups = <String>[];

const sportsCarId = '35e4c570-cb02-4466-ae86-d670b3fb05ab';
const retiredGiftId = 'e1e65664-37f8-4cfd-9640-3bb035723b98';

class CarGiftRepository extends GiftRepository {
  CarGiftRepository(super.db);
  @override
  Future<Map<String, String>> participantNamesForVerifiedEvent(
    Map<String, dynamic> event,
  ) async => {
    if (event['sender_id'] != null) event['sender_id'].toString(): 'Sender',
    if (event['receiver_id'] != null)
      event['receiver_id'].toString(): 'Receiver',
  };
  @override
  Future<String?> approvedAnimationUrl(String giftId) async {
    if (privateAnimalVapGiftIds.contains(giftId)) {
      privateMediaLookups.add(giftId);
      return null;
    }
    throw StateError('Bundled Sports Car should never request retired media');
  }
}

Map<String, dynamic> event(String id, String giftId, {bool history = false}) => {
  'id': id,
  'gift_id': giftId,
  'sender_id': '11111111-1111-4111-8111-111111111111',
  'receiver_id': '22222222-2222-4222-8222-222222222222',
  'unit_price': 100000,
  'quantity': 3,
  'scope': 'room',
  'created_at': history
      ? '2026-10-18T01:00:00Z'
      : DateTime.now().toUtc().toIso8601String(),
};

void main() {
  late SupabaseClient db;
  late StreamController<List<Map<String, dynamic>>> events;

  setUp(() {
    privateMediaLookups.clear();
    db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    events = StreamController<List<Map<String, dynamic>>>.broadcast();
  });
  tearDown(() async {
    await events.close();
    await db.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          giftRepositoryProvider.overrideWithValue(CarGiftRepository(db)),
          giftCatalogProvider.overrideWith(
            (_) async => [
              const Gift(
                sportsCarId,
                'Sports Car',
                'premium',
                100000,
                'assets/gifts/free/sports_car.png',
              ),
            ],
          ),
          verifiedGiftAnimationProvider((roomId: 'room', countryCode: 'PK'))
              .overrideWith((_) async* {
                // Initial history should never replay after room entry.
                yield [event('history', sportsCarId, history: true)];
                yield* events.stream;
              }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VerifiedGiftBroadcast(roomId: 'room', countryCode: 'PK'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(FreeGiftSvgaOverlay), findsNothing);
  }

  testWidgets('retired non-car gift events cannot play after cleanup', (
    tester,
  ) async {
    await mount(tester);
    events.add([event('retired', retiredGiftId)]);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(FreeGiftSvgaOverlay), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('server-verified Sports Car uses its real bundled SVGA', (
    tester,
  ) async {
    await mount(tester);
    events.add([event('car-now', sportsCarId)]);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.byType(FreeGiftSvgaOverlay), findsOneWidget);
    final effect = tester.widget<FreeGiftSvgaOverlay>(
      find.byType(FreeGiftSvgaOverlay),
    );
    expect(effect.source, 'assets/gifts/free/sports_car.svga');
    expect(effect.giftName, 'Sports Car');
    expect(effect.quantity, 3);
    await tester.pumpWidget(const SizedBox());
  });
  for (final giftId in privateAnimalVapGiftIds) {
    testWidgets('verified private gift $giftId requests protected VAP media', (
      tester,
    ) async {
      await mount(tester);
      events.add([event('private-now', giftId)]);
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(privateMediaLookups, contains(giftId));
      expect(find.byType(FreeGiftSvgaOverlay), findsNothing);
      expect(find.byType(NimzoGiftCelebration), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

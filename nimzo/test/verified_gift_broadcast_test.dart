import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_video_overlay.dart';
import 'package:nimzo/features/gifts/verified_gift_broadcast.dart';

class MediaRepository extends GiftRepository {
  MediaRepository(super.db);
  final pending = <String, Completer<String?>>{};
  @override
  Future<String?> approvedAnimationUrl(String giftId) =>
      pending.putIfAbsent(giftId, () => Completer<String?>()).future;
}

Map<String, dynamic> event(String id, String giftId) => {
      'id': id,
      'gift_id': giftId,
      'unit_price': 1000000,
      'quantity': 3,
      'scope': 'room',
      'created_at': '2026-10-09T01:00:00Z',
    };

void main() {
  late SupabaseClient db;
  late MediaRepository repo;
  late StreamController<List<Map<String, dynamic>>> events;
  setUp(() {
    db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repo = MediaRepository(db);
    events = StreamController<List<Map<String, dynamic>>>();
  });
  tearDown(() async {
    unawaited(events.close());
    await db.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          giftRepositoryProvider.overrideWithValue(repo),
          giftCatalogProvider.overrideWith(
            (_) async => [
              const Gift(
                'ce25005c-bb88-4e99-9891-e3d89e25e027',
                'Royal Dragon',
                'svip',
                2500000,
                null,
              ),
            ],
          ),
          verifiedGiftAnimationProvider((roomId: 'room', countryCode: 'PK'))
              .overrideWith((_) async* {
            // A real Supabase stream always starts with a history snapshot.
            // Seed that snapshot before consuming live additions.
            yield [event('history', 'history')];
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
    await tester.pumpAndSettle();
    expect(repo.pending, isEmpty);
  }

  testWidgets('stalled approved-media lookup releases the verified queue', (
    tester,
  ) async {
    await mount(tester);
    events.add([event('first', 'first'), event('second', 'second')]);
    await tester.pump();
    await tester.pump();
    expect(repo.pending.containsKey('first'), isTrue);
    for (var tick = 0; tick < 15; tick++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(repo.pending.containsKey('second'), isTrue);
    repo.pending['first']!.complete('https://example.com/late.mp4');
    await tester.pump();
    expect(find.byType(GiftVideoOverlay), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('backgrounding cancels queued and in-flight effects', (
    tester,
  ) async {
    await mount(tester);
    events.add([event('first', 'first'), event('second', 'second')]);
    await tester.pump();
    await tester.pump();
    expect(repo.pending.containsKey('first'), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repo.pending['first']!.complete(null);
    await tester.pump();
    expect(find.textContaining('ROOM GIFT'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(repo.pending.containsKey('second'), isFalse);
    // A reconnect snapshot must not replay either canceled effect.
    events.add([event('first', 'first'), event('second', 'second')]);
    await tester.pump();
    expect(find.textContaining('ROOM GIFT'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settled gift announcement uses quantity and total cost', (
    tester,
  ) async {
    await mount(tester);
    events.add([event('generic', 'ce25005c-bb88-4e99-9891-e3d89e25e027')]);
    await tester.pump();
    await tester.pump();
    repo.pending.values.single.complete(null);
    await tester.pump();
    // The gift catalog FutureProvider resolves on a subsequent frame.
    await tester.pump();
    await tester.pump();
    expect(find.text('Royal Dragon'), findsOneWidget);
    expect(find.text('× 3'), findsOneWidget);
    expect(find.text('3M coins'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

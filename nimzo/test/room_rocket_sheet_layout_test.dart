import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_leaderboard.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_widgets.dart';

void main() {
  test(
    'all six real Rocket previews preserve transparent VAP silhouettes',
    () async {
      for (var level = 1; level <= 6; level++) {
        final bytes = await File(
          'assets/room_rocket/posters/rocket_stage_$level.png',
        ).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(frame.image.width, 480);
        expect(frame.image.height, 480);
        // Fully transparent corners prevent the old opaque navy rectangle.
        expect(rgba!.getUint8(3), 0, reason: 'level $level top-left alpha');
        expect(
          rgba.getUint8(rgba.lengthInBytes - 1),
          0,
          reason: 'level $level bottom-right alpha',
        );
        var visible = 0;
        for (var offset = 3; offset < rgba.lengthInBytes; offset += 4) {
          if (rgba.getUint8(offset) > 128) visible++;
        }
        expect(
          visible,
          greaterThan(3000),
          reason: 'level $level actual artwork',
        );
        expect(visible, lessThan(480 * 480 ~/ 2));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  for (final width in [280.0, 360.0]) {
    testWidgets(
      'six tiers fit horizontally at $width with real contributors and history',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.utc(2026, 10, 21, 18);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomDiamondStatusProvider('room').overrideWith(
                (_) async => RoomDiamondStatus(
                  totalCoins: 15000000,
                  completedStages: 2,
                  progress: .5,
                  cycleStart: now,
                  serverNow: now,
                  resetAt: now.add(const Duration(hours: 2)),
                ),
              ),
              roomRocketLeaderboardProvider('room').overrideWith(
                (_) async => const [
                  RoomRocketLeader(
                    rank: 1,
                    userId: 'u',
                    nimzoId: 100005,
                    displayName: 'A contributor with a very long display name',
                    giftedCoins: 15000000,
                  ),
                ],
              ),
              roomRocketHistoryProvider('room').overrideWith(
                (_) async => [
                  DiamondBlastEvent(
                    id: 'verified',
                    roomId: 'room',
                    stage: 1,
                    cycleStart: now,
                    createdAt: now.add(const Duration(minutes: 5)),
                  ),
                ],
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.2)),
                child: child!,
              ),
              home: const Scaffold(body: RoomRocketSheet(roomId: 'room')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = tester.getRect(
          find.byKey(const ValueKey('rocket-stage-0')),
        );
        final last = tester.getRect(
          find.byKey(const ValueKey('rocket-stage-5')),
        );
        expect(first.top, last.top);
        expect(first.left, greaterThanOrEqualTo(0));
        expect(last.right, lessThanOrEqualTo(width));
        await tester.tap(find.byKey(const ValueKey('rocket-stage-5')));
        await tester.pumpAndSettle();
        expect(find.text('ROCKET 6'), findsOneWidget);
        final artwork = tester.widget<Image>(
          find.byKey(const ValueKey('selected-rocket-artwork')),
        );
        expect(
          (artwork.image as AssetImage).assetName,
          endsWith('rocket_stage_6.png'),
        );
        // Selecting a future visual must not replace the server's active progress.
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .5,
        );
        expect(find.text('15.0M gifted in this room today'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('rocket-top-1')));
        expect(find.text('ID:100005'), findsOneWidget);
        expect(find.text('15.0M'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('rocket-history-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('rocket-history-toggle')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('rocket-history-verified')),
        );
        expect(find.text('Rocket 2 · 10.0M coins'), findsOneWidget);
        expect(find.text('2026-10-21 18:05:00'), findsOneWidget);
        expect(find.text('Claim'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

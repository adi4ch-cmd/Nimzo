import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  testWidgets(
    'Explore header keeps controls visible on a 320dp Android screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            popularRoomsProvider(null).overrideWith((_) async => <Room>[]),
            newRoomsProvider.overrideWith((_) async => <Room>[]),
            myRoomsProvider.overrideWith((_) async =>
              {'recent': <Room>[], 'followed': <Room>[]}),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(1.35),
              ),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('explore-tab-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore-tab-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore-tab-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('explore-tab-3')), findsOneWidget);
      expect(find.byTooltip('Search rooms and users'), findsOneWidget);
      expect(find.byTooltip('Rankings'), findsOneWidget);
      expect(find.byTooltip('Filter by country'), findsOneWidget);
      expect(tester.takeException(), isNull,
        reason: 'No RenderFlex overflow or fake-room fallback permitted.');
    },
  );
}

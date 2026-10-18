import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  testWidgets('country bottom sheet keeps Search, All and flags accessible',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        popularRoomsProvider(null).overrideWith((_) async => <Room>[]),
        newRoomsProvider.overrideWith((_) async => <Room>[]),
        myRoomsProvider.overrideWith((_) async =>
          {'recent': <Room>[], 'followed': <Room>[]}),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter by country'));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filter'), findsOneWidget);
    expect(find.byKey(const ValueKey('room-country-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-country-all')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('room-country-search')), 'Pakistan');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('room-country-PK')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-country-all')));
    await tester.pumpAndSettle();
    expect(find.text('Apply Filter'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

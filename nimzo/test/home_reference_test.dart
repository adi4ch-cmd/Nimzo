import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  testWidgets('empty popular rooms do not render prototype users or counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [popularRoomsProvider(null).overrideWith((_) async => [])],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No rooms available yet.'), findsOneWidget);
    expect(find.textContaining('FAISALABAD'), findsNothing);
    expect(find.textContaining('128 online'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

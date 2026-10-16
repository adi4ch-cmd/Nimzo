import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  testWidgets('followed room refresh waits for the visible backend list', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<Map<String, List<Room>>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          popularRoomsProvider(null).overrideWith((_) async => []),
          myRoomsProvider.overrideWith((_) async {
            if (++calls == 1) return {'followed': <Room>[], 'recent': <Room>[]};
            return await pending.future;
          }),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Followed'));
    await tester.pumpAndSettle();
    var complete = false;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh()
        .then((_) => complete = true);
    await tester.pump();
    expect(complete, false);
    pending.complete({'followed': [], 'recent': []});
    await refresh;
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}

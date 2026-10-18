import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/presentation/create_room_screen.dart';

void main() {
  testWidgets('room photo chooser offers camera and gallery and cancels safely',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CreateRoomScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('room-photo-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-photo-gallery')), findsOneWidget);
    expect(find.text('Select Room Photo'), findsOneWidget);

    // Cancel never invokes the native image picker or touches Supabase.
    await tester.tap(find.byKey(const ValueKey('room-photo-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('room-photo-camera')), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

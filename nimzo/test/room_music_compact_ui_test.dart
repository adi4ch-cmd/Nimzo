import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/presentation/room_music_screen.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('room music sheet has usable local playback controls at ${width}dp',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const RoomMusicScreen(compact: true),
              ),
              child: const Text('Music'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Music'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('music-compact-sheet')), findsOneWidget);
      expect(find.text('No track selected'), findsOneWidget);
      expect(find.byKey(const ValueKey('music-add-from-phone')), findsOneWidget);
      expect(find.byKey(const ValueKey('music-playback-seek')), findsOneWidget);
      expect(find.byKey(const ValueKey('music-volume')), findsOneWidget);
      expect(find.byKey(const ValueKey('music-compact-track-list')), findsNothing);
      expect(find.textContaining('Personal playback only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

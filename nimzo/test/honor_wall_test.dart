import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/honors/honor_milestone.dart';
import 'package:nimzo/features/honors/honor_repository.dart';
import 'package:nimzo/features/honors/honor_wall_screen.dart';

void main() {
  testWidgets('honors show real eligibility, progress and category filtering',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        honorMilestonesProvider.overrideWith((_) async => [
              HonorMilestone(
                  code: 'first_gift',
                  title: 'First gift',
                  category: 'Giving',
                  description: 'Send a gift to another member.',
                  progress: 1,
                  target: 1,
                  earned: true,
                  earnedAt: DateTime.utc(2026, 10, 21)),
              const HonorMilestone(
                  code: 'rounds_10',
                  title: 'Ten rounds',
                  category: 'Games',
                  description: 'Complete ten rounds.',
                  progress: 2,
                  target: 10,
                  earned: false),
            ])
      ],
      child: const MaterialApp(home: HonorWallScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 earned'), findsOneWidget);
    expect(find.byKey(const ValueKey('honor-first_gift')), findsOneWidget);
    expect(find.text('2 / 10 · In progress'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Games'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('honor-first_gift')), findsNothing);
    expect(find.byKey(const ValueKey('honor-rounds_10')), findsOneWidget);
    expect(find.textContaining('Earned 2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server failure exposes retry instead of invented honors',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        honorMilestonesProvider
            .overrideWith((_) async => throw StateError('offline'))
      ],
      child: const MaterialApp(home: HonorWallScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('honor-earned-total')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}

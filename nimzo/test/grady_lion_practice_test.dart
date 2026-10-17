import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/grady_lion_practice.dart';

void main() {
  test('Grady Lion practice enforces six distinct picks across eight outcomes', () {
    final selection = GradyLionPracticeSelection();
    expect(GradyLionPracticeSelection.options, hasLength(8));
    for (var i = 0; i < 6; i++) {
      expect(selection.toggle(i), isTrue);
    }
    expect(selection.count, 6);
    expect(selection.toggle(6), isFalse);
    expect(selection.toggle(7), isFalse);
    expect(selection.count, 6);
    expect(selection.toggle(2), isTrue); // Unselect is always allowed.
    expect(selection.toggle(6), isTrue);
    expect(selection.count, 6);
    expect(selection.selected.contains(6), isTrue);
    expect(() => selection.toggle(8), throwsRangeError);
    selection.clear();
    expect(selection.count, 0);
  });

  testWidgets('practice draws never show wallet winnings or real bets',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: GradyLionPracticeScreen()),
    );
    expect(find.text('0 / 6 selected'), findsOneWidget);
    expect(find.textContaining('No coins are charged or awarded'), findsOneWidget);
    final draw = find.byKey(const ValueKey('grady-practice-draw'));
    expect(tester.widget<FilledButton>(draw).onPressed, isNull);

    for (var i = 0; i < 6; i++) {
      final option = find.byKey(ValueKey('grady-practice-option-$i'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
    }
    expect(find.text('6 / 6 selected'), findsOneWidget);
    await tester.ensureVisible(draw);
    await tester.tap(draw);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byKey(const ValueKey('grady-practice-result')), findsOneWidget);
    expect(find.textContaining('No coin payout.'), findsOneWidget);
    expect(find.textContaining('You won'), findsNothing);

    final reset = find.byKey(const ValueKey('grady-practice-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump();
    expect(find.text('0 / 6 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('grady-practice-result')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

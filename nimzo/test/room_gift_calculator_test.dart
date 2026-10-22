import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';

void main() {
  testWidgets(
      'gift calculator computes exact total and clears without a wallet call',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoomToolForm(tool: 'Calculator'))));
    await tester.enterText(
        find.byKey(const ValueKey('calculator-price')), '12500');
    await tester.enterText(
        find.byKey(const ValueKey('calculator-quantity')), '99');
    await tester.pump();
    expect(find.text('1,237,500 coins'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('1,237,500 coins'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

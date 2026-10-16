import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/gift_celebration_overlay.dart';

void main() {
  testWidgets('settled room gift animates with real price/name/quantity',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NimzoGiftCelebration(
          key: const ValueKey('settled-event-1'),
          giftName: 'Royal Dragon',
          sender: 'Sender',
          recipient: 'Receiver',
          quantity: 3,
          unitPrice: 2500000,
          onFinished: () => completed++,
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Royal Dragon'), findsOneWidget);
    expect(find.text('× 3'), findsOneWidget);
    expect(find.text('Sender  →  Receiver'), findsOneWidget);
    expect(find.text('NIMZO GIFT'), findsOneWidget);
    expect(find.textContaining('Hilo'), findsNothing);
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 3800));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small gift animations are non-interactive and finish quickly',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const Center(child: Text('Room content')),
            NimzoGiftCelebration(
              giftName: 'Rose',
              sender: 'A',
              recipient: 'B',
              quantity: 1,
              unitPrice: 500,
              onFinished: () => done++,
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('NIMZO GIFT'), findsOneWidget);
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing room view stops playback without sending anything',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: NimzoGiftCelebration(
        giftName: 'Coffee',
        sender: 'A',
        recipient: 'B',
        quantity: 10,
        unitPrice: 5000,
        onFinished: () => done++,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));
    expect(done, 0);
    expect(tester.takeException(), isNull);
  });
}

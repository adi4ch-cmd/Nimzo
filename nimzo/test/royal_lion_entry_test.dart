import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/royal_lion_entry.dart';

void main() {
  testWidgets('original king entrance animates and can be skipped', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        height: 750, width: 380,
        child: RoyalLionEntry(name: 'NIMZO TEST KING',
          onFinished: () => skipped++),
      )),
    ));
    expect(find.text('THE KING HAS ARRIVED'),findsOneWidget);
    expect(find.text('NIMZO TEST KING'),findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(),isNull);
    await tester.tap(find.byTooltip('Skip royal entrance'));
    expect(skipped,1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion displays stable royal artwork', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations:true),
        child: SizedBox(
          height:700,width:375,
          child:RoyalLionEntry(name:'Member'),
        ),
      ),
    ));
    expect(find.byType(CustomPaint),findsWidgets);
    expect(find.text('THE KING HAS ARRIVED'),findsOneWidget);
    expect(tester.hasRunningAnimations,isFalse);
    expect(tester.takeException(),isNull);
  });
}

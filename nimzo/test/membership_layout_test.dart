import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/willchill_membership_showcase.dart';

void main() {
  for (final kind in ['vip', 'svip']) {
    testWidgets('$kind tier artwork fits small screens and large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (var tier = 1; tier <= (kind == 'svip' ? 8 : 7); tier++) {
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
              body: SingleChildScrollView(
            child: WillChillMembershipShowcase(
                kind: kind,
                tier: tier,
                ownedLevel: 0,
                onTierChanged: (_) {},
                onPreviewEntrance: () {}),
          )),
        )));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing,
            reason: 'Every tier must load its own artwork');
        expect(tester.takeException(), isNull, reason: '$kind $tier');
      }
    });
  }
}

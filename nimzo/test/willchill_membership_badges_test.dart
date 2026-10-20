import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/willchill_membership_badges.dart';

void main() {
  testWidgets('real membership labels remain visible without media files',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: WillChillMembershipBadges(svipLevel: 8, vipLevel: 7),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SVIP 8'), findsOneWidget);
    expect(find.text('VIP 7'), findsOneWidget);
  });

  testWidgets('zero membership does not show premium badges',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: WillChillMembershipBadges(svipLevel: 0, vipLevel: 0),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('willchill-membership-badges')),
        findsNothing);
  });
}

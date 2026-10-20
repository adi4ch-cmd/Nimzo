import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/willchill_membership_badges.dart';

void main() {
  testWidgets('original media badges keep accurate accessible membership labels',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: WillChillMembershipBadges(svipLevel: 8, vipLevel: 7),
      ),
    ));
    await tester.pumpAndSettle();
    // Original image assets are now bundled. Validate accessible level labels
    // rather than expecting text-only artwork fallbacks.
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == 'SVIP 8'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == 'VIP 7'),
      findsOneWidget,
    );
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

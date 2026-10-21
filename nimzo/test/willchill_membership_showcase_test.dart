import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/willchill_membership_showcase.dart';

void main() {
  testWidgets(
      'video layout uses Identification and a three-column benefit grid',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: WillChillMembershipShowcase(
        kind: 'vip',
        tier: 1,
        ownedLevel: 0,
        onTierChanged: (_) {},
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Identification'), findsOneWidget);
    expect(find.text('Exclusive privilege'), findsOneWidget);
    expect(find.text('Avatar Frame'), findsOneWidget);
    expect(find.text('Chat Bubble'), findsOneWidget);
    expect(find.byKey(const ValueKey('membership-vip-identification-grid')),
        findsOneWidget);
  });
  for (final kind in ['vip', 'svip']) {
    testWidgets('$kind places badge and nameplate in composed tier cards',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SingleChildScrollView(
            child: WillChillMembershipShowcase(
          kind: kind,
          tier: kind == 'svip' ? 8 : 7,
          ownedLevel: 0,
          onTierChanged: (_) {},
        )),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('membership-$kind-identity')), findsOneWidget);
      expect(
          find.byKey(ValueKey('membership-$kind-nameplate')), findsOneWidget);
      expect(find.text('Original theme artwork preview'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('SVIP8 shows original artwork as a page, not raw asset inventory',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WillChillMembershipShowcase(
            kind: 'svip',
            tier: 8,
            ownedLevel: 0,
            onTierChanged: (_) {},
            onPreviewEntrance: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('SVIP 8'), findsWidgets);
    expect(find.text('Tier preview'), findsOneWidget);
    expect(
        find.text('No active SVIP tier on your NIMZO account'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('willchill-svip-crown-8')), findsOneWidget);
    expect(find.textContaining('files'), findsNothing);
    expect(find.textContaining('bg_svip8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIP 7 preview cannot claim membership for unsigned user',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WillChillMembershipShowcase(
            kind: 'vip',
            tier: 7,
            ownedLevel: 0,
            onTierChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('VIP 7'), findsWidgets);
    expect(
        find.text('No active VIP tier on your NIMZO account'), findsOneWidget);
    expect(find.textContaining('files'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final kind in ['vip', 'svip']) {
    testWidgets('$kind tier 10 has an honest original fallback',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: WillChillMembershipShowcase(
            kind: kind, tier: 10, ownedLevel: 10, onTierChanged: (_) {}),
      )));
      await tester.pump();
      expect(find.byKey(ValueKey('membership-$kind-original-tier-10')),
          findsOneWidget);
      expect(find.text('NIMZO signature style'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

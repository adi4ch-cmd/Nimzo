import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_pack_runtime.dart';
import 'package:nimzo/features/premium/membership_status.dart';

MembershipStatus _status({int vip = 0, int svip = 0, bool retired = false}) =>
    MembershipStatus.fromJson({
      'retired': retired,
      'vip_level': vip,
      'svip_level': svip,
      'purchases_enabled': false,
      'claims_enabled': false,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every active VIP and SVIP level receives a distinct tier theme', () {
    final vipColors = <Color>{};
    final svipColors = <Color>{};
    for (var tier = 1; tier <= 10; tier++) {
      final vip = MembershipPackTheme.fromStatus(_status(vip: tier));
      final svip = MembershipPackTheme.fromStatus(_status(svip: tier));
      expect(vip?.label, 'VIP $tier');
      expect(svip?.label, 'SVIP $tier');
      vipColors.add(vip!.dark);
      svipColors.add(svip!.dark);
    }
    expect(vipColors.length, 10);
    expect(svipColors.length, 10);
  });

  test('SVIP takes visual precedence and absent/retired memberships do not render', () {
    final both = MembershipPackTheme.fromStatus(_status(vip: 3, svip: 7));
    expect(both?.label, 'SVIP 7');
    expect(MembershipPackTheme.fromStatus(_status()), isNull);
    expect(MembershipPackTheme.fromStatus(_status(vip: 5, retired: true)),
        isNull);
  });

  testWidgets('verified live cosmetics render on profile, voice room and chat',
      (tester) async {
    for (final kind in ['vip', 'svip']) {
      for (final tier in [1, 5, 10]) {
        final status = _status(
            vip: kind == 'vip' ? tier : 0,
            svip: kind == 'svip' ? tier : 0);
        await tester.pumpWidget(ProviderScope(
          key: ValueKey('$kind-$tier'),
          overrides: [
            effectiveMembershipProvider('person')
                .overrideWith((_) async => status),
          ],
          child: MaterialApp(
            home: Scaffold(body: Column(children: [
              MembershipPackAvatar(
                userId: 'person', size: 48,
                child: const CircleAvatar(child: Text('A')),
              ),
              const MembershipPackNameplate(
                userId: 'person', child: Text('User')),
              const MembershipPackChatBubble(
                userId: 'person', child: Text('Hello')),
              const MembershipPackRoomBanner(ownerId: 'person'),
              const Expanded(child: MembershipPackRoomAtmosphere(
                  ownerId: 'person', child: SizedBox.expand())),
            ])),
          ),
        ));
        await tester.pumpAndSettle();
        for (final name in ['avatar', 'nameplate', 'chat', 'room', 'atmosphere']) {
          expect(
              find.byKey(ValueKey('membership-pack-$name-$kind-$tier')),
              findsOneWidget,
              reason: '$name must render for $kind $tier');
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('no active tier causes cosmetic wrappers to fail closed',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effectiveMembershipProvider('person')
            .overrideWith((_) async => _status(retired: true, vip: 10)),
      ],
      child: const MaterialApp(home: Scaffold(body: Column(children: [
        MembershipPackAvatar(userId: 'person', size: 48,
            child: CircleAvatar(child: Text('A'))),
        MembershipPackNameplate(userId: 'person', child: Text('User')),
        MembershipPackChatBubble(userId: 'person', child: Text('Hello')),
        MembershipPackRoomBanner(ownerId: 'person'),
      ]))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('membership-pack-avatar-vip-10')),
        findsNothing);
    expect(find.byKey(const ValueKey('membership-pack-nameplate-vip-10')),
        findsNothing);
    expect(find.byKey(const ValueKey('membership-pack-chat-vip-10')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native VIP entry animates at every tier without media assets',
      (tester) async {
    for (var tier = 1; tier <= 10; tier++) {
      final theme = MembershipPackTheme.fromStatus(_status(vip: tier))!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MembershipPackEntranceBanner(theme: theme),
        ),
      ));
      await tester.pump();
      expect(find.byKey(ValueKey('membership-pack-entry-vip-$tier')),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    }
  });
}

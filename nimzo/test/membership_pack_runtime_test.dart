import 'package:flutter/material.dart';
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

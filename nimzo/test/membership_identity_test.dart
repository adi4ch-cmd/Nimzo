import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';

void main() {
  testWidgets(
      'verified badges hide expired membership and respect the server tier',
      (tester) async {
    for (final tier in [0, 10]) {
      await tester.pumpWidget(ProviderScope(
        key: ValueKey(tier),
        overrides: [
          membershipPresentationsProvider.overrideWith((_) async => []),
          membershipBundledPresentationsProvider.overrideWith((_) async => []),
          effectiveMembershipProvider('member').overrideWith((_) async =>
              MembershipStatus.fromJson({'vip_level': tier, 'svip_level': 0}))
        ],
        child: const MaterialApp(
            home: Scaffold(body: VerifiedMembershipIdentity(userId: 'member'))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('VIP 10'), tier == 10 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('top-tier entrance animates and then clears without fake media',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          membershipPresentationsProvider.overrideWith((_) async => []),
          membershipBundledPresentationsProvider.overrideWith((_) async => []),
          currentUserIdProvider.overrideWithValue('member'),
          effectiveMembershipProvider('member').overrideWith((_) async =>
              MembershipStatus.fromJson({'vip_level': 0, 'svip_level': 10})),
        ],
        child: const MaterialApp(
            home: Scaffold(body: VerifiedOwnMembershipEntrance()))));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final opacity = tester.widget<Opacity>(find.byType(Opacity).last);
    expect(opacity.opacity, greaterThan(0));
    expect(find.text('SVIP 10 · Welcome to the room'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 0);
    expect(tester.takeException(), isNull);
  });
}

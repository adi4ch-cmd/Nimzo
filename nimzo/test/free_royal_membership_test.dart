import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/membership/royal_membership_repository.dart';
import 'package:nimzo/features/membership/royal_membership_screen.dart';

void main() {
  test('8 unique VIP and 9 unique SVIP theme definitions', () {
    expect(royalThemes.where((e) => e.kind == RoyalKind.vip).length, 8);
    expect(royalThemes.where((e) => e.kind == RoyalKind.svip).length, 9);
    expect(royalThemes.map((e) => e.label).toSet().length, 17);
    expect(royalThemes.every((e) => e.name.isNotEmpty), isTrue);
  });

  test('legacy paid level never determines new free selection', () {
    const empty = RoyalSelection();
    expect(empty.visibleTheme, null);
    expect(empty.vipTier, null);
    final selected = RoyalSelection.fromJson({
      'vip_tier': 3,
      'svip_tier': 9,
      'display_kind': 'svip',
      'vip_level': 10, // ignored retired field
    });
    expect(selected.visibleTheme?.label, 'SVIP9');
    expect(selected.tierFor(RoyalKind.vip), 3);
    expect(RoyalSelection.fromJson({
      'vip_tier': 40, 'svip_tier': -1, 'display_kind': 'vip',
    }).visibleTheme, isNull);
  });

  for (final kind in RoyalKind.values) {
    testWidgets('${kind.title} free screen has full collection without prices',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: MaterialApp(home: RoyalMembershipScreen(kind: kind)),
      ));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('ROYAL MEMBERSHIP'), findsOneWidget);
      expect(find.text('${kind.title}1'), findsWidgets);
      expect(find.textContaining('4000000'), findsNothing);
      expect(find.textContaining('30 days'), findsNothing);
      expect(find.textContaining('Buy'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/profile_screen.dart';
import 'package:nimzo/features/profile/me_screen.dart';
import 'package:nimzo/features/profile/levels_screen.dart';

void main() {
  test('wealth palette boundaries and separate Charm/Active palette', () {
    const cases = {
      1: 0xffa16207,
      20: 0xffa16207,
      21: 0xff16a34a,
      39: 0xff16a34a,
      40: 0xff2563eb,
      59: 0xff2563eb,
      60: 0xffdb2777,
      79: 0xffdb2777,
      80: 0xffdc2626,
      99: 0xffdc2626,
      100: 0xffd4a017,
      120: 0xffd4a017,
    };
    for (final entry in cases.entries) {
      expect(LevelBadge.color(0, entry.key), Color(entry.value));
      expect(LevelBadge.color(1, entry.key), const Color(0xff2563eb));
      expect(LevelBadge.color(2, entry.key), const Color(0xffdc2626));
    }
  });
  for (var kind = 0; kind < 3; kind++) {
    testWidgets('Me badge $kind opens corresponding details', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('u'),
            profileProvider('u').overrideWith(
              (_) async => const Profile(
                id: 'u',
                nimzoId: 987654,
                displayName: 'Amina',
                countryName: 'Canada',
                wealthCoins: 1250000,
                charmDiamonds: 2345,
                activePoints: 89,
              ),
            ),
            profileStatsProvider('u').overrideWith((_) async => {}),
          ],
          child: const MaterialApp(home: MeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final id = tester.getRect(find.byKey(const ValueKey('me-copy-id')));
      final badges = tester.getRect(
        find.byKey(const ValueKey('me-level-badges')),
      );
      expect(badges.top, greaterThanOrEqualTo(id.bottom));
      expect(badges.height, lessThan(40));
      expect(find.text('ID:987654 | Canada'), findsOneWidget);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('me-copy-id')));
      await tester.pump();
      expect(copied, '987654');
      await tester.tap(find.byKey(ValueKey('me-level-$kind')));
      await tester.pumpAndSettle();
      expect(find.byType(LevelsScreen), findsOneWidget);
      expect(find.text('Level unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          ['coins sent', 'diamonds received', 'activity points'][kind],
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('next-level requirement unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

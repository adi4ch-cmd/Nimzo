import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/profile_screen.dart';

void main() {
  Future<void> openProfile(
    WidgetTester tester, {
    bool giftError = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = SupabaseClient('https://example.supabase.co', 'test-key');
    db.auth.stopAutoRefresh();
    addTearDown(db.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u'),
          profileProvider('u').overrideWith(
            (_) async => const Profile(
              id: 'u',
              nimzoId: 101,
              displayName: 'Amina',
              wealthLevel: 0,
              charmLevel: 0,
              activeLevel: 0,
            ),
          ),
          profileStatsProvider('u').overrideWith((_) async => {'followers': 7}),
          profileTagsProvider('u').overrideWith((_) async => []),
          profileCoupleProvider('u').overrideWith((_) async => null),
          profileModelsProvider('u').overrideWith((_) async => []),
          profileMomentsProvider('u').overrideWith((_) async => []),
          profileGiftsProvider('u').overrideWith((_) async {
            if (giftError) throw StateError('backend unavailable');
            return [
              {'name': 'Rose', 'quantity': 12},
            ];
          }),
          profileAchievementsProvider('u').overrideWith((_) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'profile presents backend received gifts and avoids fabricated badges',
    (tester) async {
      await openProfile(tester);
      expect(find.text('Amina'), findsOneWidget);
      expect(find.text('Wealth'), findsNothing);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();
      expect(find.text('Rose'), findsOneWidget);
      expect(find.text('× 12'), findsOneWidget);
      expect(find.text('No gifts received yet'), findsNothing);
    },
  );

  testWidgets(
    'profile gift failure remains a retryable error rather than empty data',
    (tester) async {
      await openProfile(tester, giftError: true);
      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();
      expect(find.text('Gifts could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No gifts received yet'), findsNothing);
    },
  );
}

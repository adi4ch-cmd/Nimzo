import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/profile_screen.dart';
import 'package:nimzo/features/profile/levels_screen.dart';
import 'package:nimzo/features/profile/profile_collections.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';

void main() {
  Future<void> openProfile(
    WidgetTester tester, {
    bool linked = false,
    bool profileCard = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Supabase owns a JSON isolate. Create and dispose it in real async time;
    // widget-test fake time cannot deliver isolate lifecycle messages.
    final db = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u'),
          storeVisualEquipmentProvider('u')
              .overrideWith((_) async => profileCard
                  ? {
                      'Profile Card': const CosmeticMedia(
                          'fixture-profile-card',
                          'Profile Card',
                          'Fixture card',
                          'assets/premium_store/willchill/chat_send_id_card_bg.png',
                          CosmeticMediaKind.image)
                    }
                  : <String, CosmeticMedia>{}),
          profileProvider('u').overrideWith(
            (_) async => const Profile(
              id: 'u',
              nimzoId: 101,
              displayName: 'Amina',
              wealthCoins: 1250000,
              charmDiamonds: 2345,
              activePoints: 89,
              wealthLevel: 0,
              charmLevel: 0,
              activeLevel: 0,
            ),
          ),
          profileStatsProvider('u').overrideWith((_) async => {'followers': 7}),
          profileTagsProvider('u').overrideWith((_) async => []),
          profileCoupleProvider('u').overrideWith(
            (_) async => linked
                ? {
                    'user_a': 'u',
                    'user_b': 'partner',
                    'created_at': '2026-10-01T00:00:00Z',
                  }
                : null,
          ),
          profileProvider('partner').overrideWith(
            (_) async => const Profile(
              id: 'partner',
              nimzoId: 102,
              displayName: 'Partner',
            ),
          ),
          profileModelsProvider('u').overrideWith((_) async => []),
          profileMomentsProvider('u').overrideWith((_) async => []),
          profileAchievementsProvider('u').overrideWith((_) async => []),
          for (final kind in ProfileCollection.values)
            profileCollectionProvider(('u', kind))
                .overrideWith((_) async => []),
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
      'equipped profile background remains visible behind header controls',
      (tester) async {
    await openProfile(tester, profileCard: true);
    final cover =
        tester.widget<Container>(find.byKey(const ValueKey('profile-cover')));
    final decoration = cover.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.image, isNull);
    final frame = find.byWidgetPredicate(
        (w) => w is EquippedCosmetic && w.category == 'Profile Card');
    expect(
        find.descendant(
            of: frame,
            matching: find.byWidgetPredicate((w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    Colors.white.withValues(alpha: .92))),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (var kind = 0; kind < 3; kind++) {
    testWidgets('public profile badge $kind opens its category', (
      tester,
    ) async {
      await openProfile(tester);
      await tester.tap(find.byKey(ValueKey('profile-level-$kind')));
      await tester.pumpAndSettle();
      final screen = tester.widget<LevelsScreen>(find.byType(LevelsScreen));
      expect(screen.initialKind, kind);
      expect(screen.userId, 'u');
      expect(find.text('Level unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('badge distinguishes unavailable total from a real zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ProfileProgressBadge(kind: 0, level: 0),
              ProfileProgressBadge(kind: 1, level: 0, total: 0),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Total unavailable'), findsOneWidget);
    expect(find.text('0 diamonds'), findsOneWidget);
    expect(find.text('Level unavailable'), findsNWidgets(2));
    expect(find.text('Lv 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile avatar overlaps the approved 130px cover', (
    tester,
  ) async {
    await openProfile(tester);
    final cover = tester.getRect(find.byKey(const ValueKey('profile-cover')));
    final avatar = tester.getRect(find.byKey(const ValueKey('profile-avatar')));
    expect(cover.height, 130);
    expect(avatar.width, 78);
    expect(avatar.top, lessThan(cover.bottom));
    expect(avatar.bottom, greaterThan(cover.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked owner can still manage outstanding CP invitations', (
    tester,
  ) async {
    await openProfile(tester, linked: true);
    expect(find.text('CP invitations'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile omits retired gift history and keeps real level badges',
    (tester) async {
      await openProfile(tester);
      expect(find.text('Amina'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('profile-level-badges')), findsOneWidget);
      expect(find.text('1,250,000 coins'), findsNothing);
      expect(find.text('2,345 diamonds'), findsNothing);
      expect(find.text('89 points'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      final id = tester.getRect(find.text('ID:101 · '));
      final badges = tester.getRect(
        find.byKey(const ValueKey('profile-level-badges')),
      );
      expect(badges.top, greaterThanOrEqualTo(id.bottom));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
      expect(find.text('Gifts'), findsNothing);
      expect(find.byKey(const ValueKey('all-received-gifts')), findsNothing);
      // Old gift history, list, and badges are gone. The page itself loads.
      expect(tester.takeException(), isNull);
    },
  );
}

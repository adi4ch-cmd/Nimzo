import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';
import 'package:nimzo/core/services/nimzo_content_sync.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/auth/presentation/tingle_login_screen.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/home/party_screen.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/messages/messages_screen.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/profile_setup_screen.dart';
import 'package:nimzo/features/profile/tingle_me_screen.dart';
import 'package:nimzo/features/rooms/presentation/create_room_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_user_sheet.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/social/tingle_friends_screen.dart';
import 'package:nimzo/features/social/family_screen.dart';
import 'package:nimzo/features/social/family_repository.dart';
import 'package:nimzo/features/store/store_screen.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';
import 'package:nimzo/features/social/social_screens.dart';
import 'package:nimzo/features/profile/levels_screen.dart';
import 'package:nimzo/features/profile/profile_screen.dart';
import 'package:nimzo/features/profile/profile_collections.dart';
import 'package:nimzo/features/profile/tingle_tasks_screen.dart';
import 'package:nimzo/features/profile/tingle_daily_checkin_screen.dart';
import 'package:nimzo/features/discover/ranking_screen.dart';
import 'package:nimzo/features/discover/leaderboard_repository.dart';

const account = Profile(
    id: 'review',
    nimzoId: 100001,
    displayName: 'Review account',
    username: 'review',
    gender: 'Male',
    countryCode: 'SA',
    countryName: 'Saudi Arabia');

Future<void> capture(WidgetTester tester, String name, GlobalKey key) async {
  const directory = String.fromEnvironment('NIMZO_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> loadReviewFonts() async {
  await (FontLoader('packages/lucide_flutter/LucideIcons')
        ..addFont(rootBundle.load('packages/lucide_flutter/assets/lucide.ttf')))
      .load();
  for (final font in [
    ('Roboto', 'test/fonts/Roboto-Regular.ttf'),
    (
      'MaterialIcons',
      '../flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    ),
  ]) {
    final data = font.$1 == 'MaterialIcons'
        ? await rootBundle.load('fonts/MaterialIcons-Regular.otf')
        : ByteData.sublistView(File(font.$2).readAsBytesSync());
    await (FontLoader(font.$1)..addFont(Future.value(data))).load();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('walkthrough surfaces and privilege navigation fit ${width}dp',
        (tester) async {
      tester.view.physicalSize = Size(width, width * 2400 / 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadReviewFonts();
      final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.invalid', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final screens = <String, Widget>{
        'login': const TingleLoginScreen(),
        'home': const HomeScreen(),
        'party': const PartyScreen(),
        'moments': const MomentsScreen(),
        'messages': const MessagesScreen(),
        'profile': const TingleMeScreen(),
        'public-profile': const ProfileScreen(),
        'mini-profile': const Scaffold(
            body: RoomUserSheet(
                roomId: 'review-room',
                userId: 'review',
                seatNo: 1,
                muted: false)),
        'profile-details': const ProfileSetupScreen(edit: true),
        'create-room': const CreateRoomScreen(),
        'friends': const TingleFriendsScreen(),
        'family': const FamilyScreen(),
        'cp': const CoupleRequestsScreen(),
        'cp-gallery': const Scaffold(
            body: SingleChildScrollView(child: CpRewardGallery())),
        'store': const RoyalStoreScreen(),
        'composer': const CreateMomentScreen(),
        'ranking': const RankingScreen(),
        'levels': const LevelsScreen(),
        'tasks': const TingleTasksScreen(),
        'checkin-unavailable': const TingleDailyCheckinScreen(),

      };
      const requested = String.fromEnvironment('NIMZO_UI_SURFACES');
      for (final entry in screens.entries) {
        if (requested.isNotEmpty && !requested.split(',').contains(entry.key))
          continue;
        // ignore: avoid_print
        print('Rendering ${entry.key} at $width');
        final boundary = GlobalKey();
        Widget screenForRoute(GoRouterState state) {
          if (entry.key != 'home') return entry.value;
          final requestedTab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return HomeScreen(initialTab: requestedTab);
        }
        final router = GoRouter(routes: [
          GoRoute(path: '/', builder: (_, state) => screenForRoute(state)),
          GoRoute(path: '/home', builder: (_, state) => screenForRoute(state)),
        ]);
        await tester.pumpWidget(ProviderScope(
            key: ValueKey(entry.key),
            overrides: [
              supabaseProvider.overrideWithValue(db),
              nimzoContentRevisionsProvider.overrideWith((_) => const Stream.empty()),
              nimzoStoreProvider.overrideWith((_) async => const NimzoStoreSnapshot(items:[],owned:{},equipped:{})),
              familyDirectoryProvider.overrideWith((_) async => []),
              currentUserIdProvider.overrideWithValue('review'),
              profileProvider('review').overrideWith((_) async => account),
              profileStatsProvider('review')
                  .overrideWith((_) async => {'following': 0, 'followers': 0}),
              walletProvider.overrideWith(
                  (_) async => throw StateError('No balance fixture')),
              popularRoomsProvider(null).overrideWith((_) async => []),
              myRoomsProvider.overrideWith((_) async => {}),
              roomProvider('review-room').overrideWith(
                  (_) async => throw StateError('No room identity fixture')),
              roomModerationProvider('review-room')
                  .overrideWith((_) async => false),
              coupleRequestsProvider.overrideWith((_) async => []),
              profileCoupleProvider('review').overrideWith((_) async => null),
              profileTagsProvider('review').overrideWith((_) async => []),
              profileModelsProvider('review').overrideWith((_) async => []),
              profileMomentsProvider('review').overrideWith((_) async => []),
              profileGiftsProvider('review').overrideWith((_) async => []),
              profileAchievementsProvider('review')
                  .overrideWith((_) async => []),
              for (final kind in ProfileCollection.values)
                profileCollectionProvider(('review', kind))
                    .overrideWith((_) async => []),
              taskProgressProvider.overrideWith((_) async => {}),
              dailyAttendanceProvider.overrideWith(
                  (_) async => throw StateError('No attendance fixture')),
              for (final kind in ['wealth', 'charm'])
                for (final period in ['weekly', 'monthly'])
                  leaderboardProvider((kind, period))
                      .overrideWith((_) async => []),
              momentsFeedProvider.overrideWith((_) async => []),
              followedMomentsAuthorsProvider.overrideWith((_) async => {}),
              conversationsProvider.overrideWith((_) async => []),
              for (var tab = 0; tab < 3; tab++)
                tinglePeopleProvider(tab).overrideWith((_) async => []),
            ],
            child: RepaintBoundary(
                key: boundary,
                child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light().copyWith(
                        textTheme: AppTheme.light()
                            .textTheme
                            .apply(fontFamily: 'Roboto')),
                  routerConfig: router))));
        await tester.pumpAndSettle();
        if (entry.key == 'login') {
          await tester.runAsync(() => precacheImage(
                const AssetImage('assets/brand/nimzo_purple_gold.png'),
                boundary.currentContext!,
              ));
          await tester.pumpAndSettle();
          expect(tester.widget<RawImage>(find.byType(RawImage).first).image,
              isNotNull,
              reason: 'Approved logo must decode before screenshot');
        }
        expect(tester.takeException(), isNull, reason: '${entry.key} $width');
        await capture(tester, '${entry.key}-${width.toInt()}', boundary);
        // ignore: avoid_print
        print('Captured ${entry.key} at $width');
        if (entry.key == 'home') {
          await tester.tap(find.byTooltip('Filter by country'));
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byKey(const ValueKey('room-country-search')), 'Saudi');
          await tester.pumpAndSettle();
          await capture(
              tester, 'home-country-filter-${width.toInt()}', boundary);
          await tester.tap(find.byTooltip('Close country filter'));
          await tester.pumpAndSettle();
          for (final index in [1, 3, 0]) {
            final tab = find.byKey(ValueKey('explore-tab-$index'));
            await tester.ensureVisible(tab);
            await tester.tap(tab);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        if (entry.key == 'party') {
          await tester.tap(find.text('Follow').first);
          await tester.pumpAndSettle();
          await capture(tester, 'party-follow-${width.toInt()}', boundary);
        }
        if (entry.key == 'profile-details') {
          final save = find.byKey(const ValueKey('modify-profile-save'));
          expect(tester.getBottomRight(save).dy,
              lessThanOrEqualTo(tester.view.physicalSize.height));
          final before = tester.getTopLeft(save);
          await tester.drag(
              find.byKey(const ValueKey('modify-profile-clean-list')),
              const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(save), before,
              reason: 'Save remains visible while details scroll');
        }
        if (entry.key == 'login') {
          await tester
              .ensureVisible(find.byKey(const ValueKey('login-terms-link')));
          await tester.tap(find.byKey(const ValueKey('login-terms-link')));
          await tester.pumpAndSettle();
          expect(find.text('Terms & Conditions'), findsOneWidget);
          expect(find.text('Terms of Service'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(TingleLoginScreen), findsOneWidget);
        }
        if (entry.key == 'messages') {
          await tester.tap(find.byTooltip('Search conversations'));
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byKey(const ValueKey('inbox-search')), 'No such person');
          await tester.pumpAndSettle();
          expect(find.text('No matching conversations'), findsOneWidget);
          await tester.tap(find.byTooltip('Search conversations'));
          await tester.pumpAndSettle();
          expect(find.text('No conversations yet'), findsOneWidget);
          expect(find.byKey(const ValueKey('inbox-search')), findsNothing);
        }
        if (entry.key == 'cp-gallery') {
          for (final kind in ['theme', 'frame', 'bubble', 'entrance']) {
            final tile = find.byKey(ValueKey('cp-preview-$kind'));
            await tester.ensureVisible(tile);
            await tester.tap(tile);
            await tester.pumpAndSettle();
            expect(
                find.text(
                    'Design preview only. CP rewards are not available to claim.'),
                findsOneWidget);
            await capture(tester, 'cp-$kind-dialog-${width.toInt()}', boundary);
            await tester.tap(find.text('Close'));
            await tester.pumpAndSettle();
          }
        }
        if (entry.key == 'composer') {
          await tester
              .tap(find.byKey(const ValueKey('moment-topic-#Photography')));
          await tester.pumpAndSettle();
          await capture(tester, 'composer-topic-${width.toInt()}', boundary);
        }
        if (entry.key == 'ranking') {
          for (final label in [
            'Monthly',
            'Daily',
            'Charm',
            'Wealth',
            'Weekly'
          ]) {
            await tester.tap(find.text(label).first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await capture(tester, 'ranking-tabs-${width.toInt()}', boundary);
        }
        if (entry.key == 'friends') {
          await tester.tap(find.byTooltip('Search friends'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('friends-search')), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    });
  }
}

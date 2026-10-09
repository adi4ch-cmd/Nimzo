import 'package:nimzo/features/vip/phoenix_room_entry.dart';

import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/app/shell.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/auth/presentation/auth_screens.dart';
import 'package:nimzo/features/auth/presentation/auth_controller.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/games/game_screen.dart';
import 'package:nimzo/features/games/game_catalog.dart';
import 'package:nimzo/features/games/games_catalog_screen.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_setup_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_settings_screen.dart';
import 'package:nimzo/features/rooms/data/room_settings_repository.dart';
import 'package:nimzo/features/discover/discover_screen.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/profile_collections.dart';
import 'package:nimzo/features/profile/profile_screen.dart';
import 'package:nimzo/features/profile/me_screen.dart';
import 'package:nimzo/features/profile/levels_screen.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/data/room_repository.dart';
import 'package:nimzo/features/rooms/data/room_chat_repository.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/rooms/presentation/room_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';
import 'package:nimzo/features/voice/voice_service.dart';
import 'package:nimzo/features/voice/voice_controller.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/messages/messages_screen.dart';
import 'package:nimzo/features/social/social_repositories.dart';
import 'package:nimzo/features/social/social_screens.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';
import 'package:nimzo/features/recharge/recharge_screen.dart';
import 'package:nimzo/features/recharge/recharge_repository.dart';
import 'package:nimzo/features/discover/ranking_screen.dart';
import 'package:nimzo/features/discover/leaderboard_repository.dart';
import 'package:nimzo/features/settings/settings_screen.dart';
import 'package:nimzo/features/store/store_repository.dart';
import 'package:nimzo/features/notifications/notifications_screen.dart';
import 'package:nimzo/features/notifications/notification_repository.dart';

// Representative data exists only in this test. No production service is called.
final fixtureRoom = Room(
  id: 'room',
  roomNo: 83200,
  name: 'FAISALABAD CAFE',
  ownerId: 'me',
  theme: 'nimzo_white',
  country: 'Pakistan',
  isPrivate: false,
  status: 'open',
  lifetimeGiftCoins: 739220000,
  createdAt: DateTime(2026),
);
const fixtureMe = Profile(
  id: 'me',
  nimzoId: 11699311,
  displayName: 'Your Name',
  countryName: 'Pakistan',
  wealthLevel: 18,
  charmLevel: 11,
  activeLevel: 26,
);
const fixtureOther = Profile(
  id: 'other',
  nimzoId: 66321,
  displayName: 'Ayesha',
  countryName: 'Pakistan',
);
final fixtureMoment = Moment(
  id: 'post',
  authorId: 'other',
  text: 'Aaj room mein maza aa gaya!',
  likes: 12,
  comments: 1,
  liked: false,
  createdAt: DateTime(2026),
);

class FixtureRoomRepository extends RoomRepository {
  FixtureRoomRepository(super.db);
  @override
  Future<Room> get(String id) async => fixtureRoom;
  @override
  Future<void> join(String id, {String? password}) async {}
  @override
  Future<void> leave(String id) async {}
}

class FixtureVoice implements VoiceService {
  @override
  Stream<bool> get connected => Stream.value(true);
  @override
  Stream<Set<String>> get speaking => Stream.value({'me'});
  @override
  Future<void> join(String id, String token) async {}
  @override
  Future<void> leave() async {}
  @override
  Future<void> setMicEnabled(bool enabled) async {}
  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  PackageInfo.setMockInitialValues(
    appName: 'Nimzo',
    packageName: 'io.nimzo.app',
    version: '1.0.6',
    buildNumber: '106',
    buildSignature: '',
  );
  testWidgets('remaining reference surfaces have reviewed phone screenshots', (
    tester,
  ) async {
    for (final font in [
      ('Roboto', 'test/fonts/Roboto-Regular.ttf'),
      ('Cinzel', 'assets/reference/fonts/Cinzel.ttf'),
      ('Poppins', 'assets/reference/fonts/Poppins-Regular.ttf'),
    ]) {
      await (FontLoader(font.$1)
            ..addFont(
              Future.value(
                  ByteData.sublistView(File(font.$2).readAsBytesSync())),
            ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/lucide_flutter/LucideIcons')
          ..addFont(
            rootBundle.load('packages/lucide_flutter/assets/lucide.ttf'),
          ))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final roots = <String, Widget>{
      'home': const HomeScreen(),
      'catalog': const GamesCatalogScreen(),
      'moments': const MomentsScreen(),
      'messages': const MessagesScreen(),
      'me': const MeScreen(),
    };
    final previews = <String, Widget>{
      ...roots,
      'auth': const LoginScreen(),
      'signup': const RegisterScreen(),
      'profile_edit': const ProfileSetupScreen(edit: true),
      'room_settings': const RoomSettingsScreen(roomId: 'room'),
      'room_tools': const RoomScreen(roomId: 'room'),
      'room_games': const RoomScreen(roomId: 'room'),
      'search': const DiscoverScreen(),
      'profile': const ProfileScreen(),
      'public_profile': const ProfileScreen(userId: 'other'),
      'room': const RoomScreen(roomId: 'room'),
      'room_profile': RoomProfilePage(room: fixtureRoom),
      'gifts': const Scaffold(
        body: GiftSheet(receiverId: 'other', roomId: 'room'),
      ),
      'comments': const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: MomentDetailScreen(id: 'post', sheet: true),
        ),
      ),
      'conversation': const ConversationScreen(otherId: 'other'),
      'levels': const LevelsScreen(),
      'wallet': const WalletScreen(),
      'recharge': const RechargeScreen(),
      'ranking': const RankingScreen(),
      'settings': const SettingsScreen(),
      'social': const SocialListScreen(kind: 'following', userId: 'me'),
      'notifications': const NotificationsScreen(),
      for (final title in [
        'Task',
        'Store',
        'Honor Wall',
        'About',
        'Account',
        'Privacy',
        'Language',
        'Help and feedback',
      ])
        title.toLowerCase().replaceAll(' ', '_'): InfoScreen(title: title),
      for (final game in NimzoRoomGames.approved)
        'game_${game.artwork}': GameScreen(slug: game.slug, roomId: 'room'),
    };
    const targetedGolden = String.fromEnvironment('NIMZO_GOLDEN_TARGET');
    for (final entry in previews.entries) {
      if (targetedGolden.isNotEmpty && entry.key != targetedGolden) continue;
      final key = ValueKey('qa-${entry.key}');
      GoRouter? router;
      Widget app;
      if (roots.containsKey(entry.key)) {
        router = GoRouter(
          initialLocation: '/${entry.key}',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, __, shell) => MainShell(shell: shell),
              branches: [
                for (final root in roots.entries)
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/${root.key}',
                        builder: (_, __) => root.value,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
        app = MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        );
      } else {
        app = MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          initialRoute: entry.key == 'auth' ? '/' : '/preview',
          routes: {
            '/': (_) => entry.key == 'auth' ? entry.value : const SizedBox(),
            '/preview': (_) => entry.value,
          },
        );
      }
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(entry.key),
          overrides: [
            phoenixEntriesProvider.overrideWith(
              (ref, room) => const Stream.empty(),
            ),
            verifiedGiftAnimationProvider.overrideWith(
              (ref, args) => const Stream.empty(),
            ),
            roomDiamondEventsProvider('room')
                .overrideWith((_) => const Stream.empty()),
            roomDiamondStatusProvider('room').overrideWith(
              (_) async => RoomDiamondStatus(
                totalCoins: 15000000,
                completedStages: 2,
                progress: .5,
                cycleStart: DateTime.utc(2026, 10, 9, 20),
                serverNow: DateTime.utc(2026, 10, 9, 21),
                resetAt: DateTime.utc(2026, 10, 10, 20),
              ),
            ),
            supabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWithValue('me'),
            authControllerProvider.overrideWith(AuthController.new),
            voiceServiceProvider.overrideWithValue(FixtureVoice()),
            ownedRoomPreviewProvider.overrideWith((_) async => fixtureRoom),
            popularRoomsProvider(null).overrideWith((_) async => [fixtureRoom]),
            roomRepositoryProvider.overrideWithValue(FixtureRoomRepository(db)),
            roomProvider('room').overrideWith((_) async => fixtureRoom),
            roomSettingsProvider('room').overrideWith(
              (_) async => const RoomSettings(
                name: 'FAISALABAD CAFE',
                theme: 'nimzo_white',
                isPrivate: false,
              ),
            ),
            seatsProvider('room').overrideWith(
              (_) => Stream.value(
                List.generate(
                  10,
                  (i) => MicSeat(
                    seatNo: i + 1,
                    userId: i == 0
                        ? 'me'
                        : i == 2
                            ? 'other'
                            : null,
                  ),
                ),
              ),
            ),
            roomSeatProfilesProvider('room').overrideWith(
              (_) async => {'me': fixtureMe, 'other': fixtureOther},
            ),
            onlineCountProvider('room').overrideWith((_) => Stream.value(128)),
            roomChatProvider('room').overrideWith(
              (_) => Stream.value([
                RoomMessage(
                  'm',
                  'me',
                  'Welcome',
                  DateTime.now().add(const Duration(minutes: 1)),
                ),
              ]),
            ),
            profileProvider('me').overrideWith((_) async => fixtureMe),
            profileProvider('other').overrideWith((_) async => fixtureOther),
            for (final id in ['me', 'other']) ...[
              profileStatsProvider(id).overrideWith(
                (_) async => {
                  'following': 16,
                  'followers': 163,
                  'visitors': 260,
                },
              ),
              profileTagsProvider(id).overrideWith(
                (_) async => ['Friendly', 'Voice Chat', 'Game Lover', 'Music'],
              ),
              profileCoupleProvider(id).overrideWith((_) async => null),
              profileModelsProvider(id).overrideWith((_) async => []),
              profileGiftsProvider(id).overrideWith(
                (_) async => [
                  {'name': 'Rose', 'quantity': 9},
                ],
              ),
              for (final kind in ProfileCollection.values)
                profileCollectionProvider((id, kind)).overrideWith(
                  (_) async => [
                    for (var i = 0;
                        i < (kind == ProfileCollection.medal ? 5 : 2);
                        i++)
                      {
                        'name': 'Owned ${kind.name} ${i + 1}',
                        'image_path':
                            'assets/reference/${kind == ProfileCollection.medal ? 'med' : kind.name}/$i.jpg',
                      },
                  ],
                ),
            ],
            if (entry.key == 'honor_wall') ...[
              royalBagProvider('me').overrideWith((_) async => const [
                    RoyalBagItem(
                      id: 'crest-1',
                      name: 'Royal Crest I',
                      image: 'assets/hilo/store/royal_1.webp',
                      equipped: true,
                    ),
                    RoyalBagItem(
                      id: 'crest-2',
                      name: 'Royal Crest II',
                      image: 'assets/hilo/store/royal_2.webp',
                      equipped: false,
                    ),
                  ]),
              royalCatalogProvider.overrideWith((_) async => const [
                    RoyalStoreItem(
                      id: 'crest-1',
                      name: 'Royal Crest I',
                      image: 'assets/hilo/store/royal_1.webp',
                      description: 'Royal collectible',
                      price: 10000,
                    ),
                    RoyalStoreItem(
                      id: 'crest-2',
                      name: 'Royal Crest II',
                      image: 'assets/hilo/store/royal_2.webp',
                      description: 'Royal collectible',
                      price: 25000,
                    ),
                    RoyalStoreItem(
                      id: 'crest-3',
                      name: 'Royal Crest III',
                      image: 'assets/hilo/store/royal_3.webp',
                      description: 'Royal collectible',
                      price: 50000,
                    ),
                  ]),
            ],
            walletProvider.overrideWith(
              (_) async => (coins: 14402, diamonds: 0),
            ),
            giftCatalogProvider.overrideWith(
              (_) async => [
                for (var i = 0; i < 13; i++)
                  Gift(
                    '$i',
                    [
                      'Spark',
                      'Eternal Rose',
                      'Love Heart',
                      'Wonder Box',
                      'Star Rocket',
                      'Golden King',
                      'Royal Couple',
                      'Royal Diamond',
                      'Legend Dragon',
                      'Emperor Crown',
                      'Galaxy Empire',
                      'Dream Kingdom',
                      'World Crown',
                    ][i],
                    'gift',
                    [
                      10,
                      100,
                      500,
                      1000,
                      10000,
                      100000,
                      1000000,
                      3000000,
                      5000000,
                      10000000,
                      15000000,
                      20000000,
                      20000000,
                    ][i],
                    null,
                  ),
              ],
            ),
            momentsFeedProvider.overrideWith((_) async => [fixtureMoment]),
            momentDetailProvider('post')
                .overrideWith((_) async => fixtureMoment),
            commentsProvider('post').overrideWith(
              (_) async => [
                {'author_id': 'me', 'body': 'Nice!'},
              ],
            ),
            conversationsProvider.overrideWith(
              (_) async => [
                {
                  'other_id': 'other',
                  'last_body': 'Thanks for the gift',
                  'unread': 2,
                },
              ],
            ),
            chatProvider('other').overrideWith(
              (_) => Stream.value([
                Message(
                  id: 'm',
                  senderId: 'other',
                  receiverId: 'me',
                  kind: 'text',
                  body: 'Thanks for the gift',
                  read: true,
                  createdAt: DateTime(2026),
                ),
              ]),
            ),
            isFollowingProvider('other').overrideWith((_) async => false),
            friendStateProvider('other')
                .overrideWith((_) async => FriendState.none),
            socialListProvider(('following', 'me'))
                .overrideWith((_) async => [fixtureOther]),
            packagesProvider.overrideWith(
              (_) async => [
                for (final d in [1, 5, 10, 50, 100, 200])
                  {'usd_cents': d * 100, 'coins': d * 500000, 'id': '$d'},
              ],
            ),
            for (final kind in ['wealth', 'charm'])
              for (final period in ['weekly', 'monthly'])
                leaderboardProvider((kind, period)).overrideWith(
                  (_) async => [
                    for (var i = 0; i < 6; i++)
                      {
                        'id': 'other',
                        'name': [
                          'BROKEN',
                          'MR CHARMING',
                          'Ice Tatty',
                          'Faisal',
                          'Ayesha',
                          'Bilal',
                        ][i],
                        'score': 'Lv ${22 - i}',
                        'nimzo_id': 83200 + i,
                      },
                  ],
                ),
            notificationsProvider('All').overrideWith(
              (_) async => [
                {
                  'title': 'Ayesha followed you',
                  'body': '',
                  'created_at': DateTime.now()
                      .subtract(const Duration(minutes: 2))
                      .toIso8601String(),
                },
              ],
            ),
          ],
          child: RepaintBoundary(key: key, child: app),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byKey(key));
      await tester.runAsync(() async {
        for (final file in Directory('assets/reference')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))) {
          await precacheImage(AssetImage(file.path), context);
        }
        if (entry.key == 'honor_wall') {
          for (final n in [1, 2, 3]) {
            await precacheImage(
              AssetImage('assets/hilo/store/royal_$n.webp'), context);
          }
        }
      });
      await tester.pump(const Duration(milliseconds: 300));
      if (entry.key == 'ranking') {
        await tester.tap(find.text('Wealth'));
        await tester.pump();
        await tester.tap(find.text('Weekly'));
        await tester.pump();
      }
      if (entry.key == 'room_tools' || entry.key == 'room_games') {
        await tester.tap(
          find.byTooltip(entry.key == 'room_tools' ? 'Party Tools' : 'Games'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/remaining/${entry.key}.png'),
      );
      expect(tester.takeException(), isNull, reason: entry.key);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      router?.dispose();
    }
  });
}

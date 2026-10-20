import '../core/providers/supabase_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_redirect.dart';
import '../features/social/social_screens.dart';
import '../features/social/family_screen.dart';
import '../features/social/tingle_friends_screen.dart';
import '../features/discover/ranking_screen.dart';
import '../features/profile/levels_screen.dart';
import '../features/profile/profile_repository.dart';
import '../features/auth/presentation/update_password_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/forgot_screen.dart';
import '../features/auth/presentation/tingle_login_screen.dart';
import '../features/auth/presentation/tingle_register_screen.dart';
import '../features/auth/presentation/verify_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/tingle_blocked_users_screen.dart';
import '../features/profile/tingle_me_screen.dart';
import '../features/profile/tingle_tasks_screen.dart';
import '../features/profile/tingle_daily_checkin_screen.dart';
import '../features/games/game_screen.dart';
import '../features/games/game_level_screen.dart';
import '../features/games/games_catalog_screen.dart';
import '../features/rooms/presentation/create_room_screen.dart';
import '../features/rooms/presentation/room_settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/events/events_screen.dart';
import '../features/store/store_screen.dart';
import '../features/home/pk_battles_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/moments/moments_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/profile_setup_screen.dart';
import '../features/recharge/recharge_screen.dart';
import '../features/rooms/presentation/room_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/wallet/tingle_coins_screen.dart';
import 'routes.dart';
import 'shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authStateProvider, (_, __) => refresh.refresh());
  ref.listen(passwordRecoveryProvider, (_, __) => refresh.refresh());
  final subscription =
      ref.read(supabaseProvider).auth.onAuthStateChange.listen((
    event,
  ) {
    if (event.event == AuthChangeEvent.passwordRecovery)
      ref.read(passwordRecoveryProvider.notifier).state = true;
    if (event.event == AuthChangeEvent.signedOut)
      ref.read(passwordRecoveryProvider.notifier).state = false;
  });
  ref.onDispose(() {
    subscription.cancel();
    refresh.dispose();
  });
  final router = GoRouter(
    refreshListenable: refresh,
    initialLocation: Routes.splash,
    redirect: (ctx, state) async {
      final auth = ref.read(authStateProvider);
      var profileReady = true;
      final user = auth.valueOrNull;
      if (!auth.isLoading &&
          user != null &&
          user.emailVerified &&
          !ref.read(passwordRecoveryProvider)) {
        try {
          final profile = await ref.read(profileProvider(user.id).future)
              .timeout(const Duration(seconds: 6));
          profileReady = (profile.displayName?.trim().isNotEmpty ?? false) &&
              profile.gender != null &&
              profile.dateOfBirth != null &&
              profile.countryCode != null;
        } catch (_) {
          // Failed or slow networks are not proof that a profile is incomplete.
          profileReady = true;
        }
      }
      return authRedirect(
        location: state.matchedLocation,
        user: auth.valueOrNull,
        loading: auth.isLoading,
        profileReady: profileReady,
        recovering: ref.read(passwordRecoveryProvider),
      );
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
          path: Routes.login, builder: (_, __) => const TingleLoginScreen()),
      GoRoute(
        path: Routes.register,
        builder: (_, __) => const TingleRegisterScreen(),
      ),
      GoRoute(path: Routes.forgot, builder: (_, __) => const ForgotScreen()),
      GoRoute(
        path: Routes.updatePassword,
        builder: (_, __) => const UpdatePasswordScreen(),
      ),
      GoRoute(path: Routes.verify, builder: (_, __) => const VerifyScreen()),
      GoRoute(
        path: Routes.profileSetup,
        builder: (_, __) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const ProfileSetupScreen(edit: true),
      ),
      GoRoute(
        path: '/create-room',
        builder: (_, __) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/room/:id/settings',
        builder: (_, s) => RoomSettingsScreen(
          roomId: s.pathParameters['id']!,
          isOwner: s.uri.queryParameters['owner'] == 'true',
        ),
      ),
      GoRoute(
        path: '/games-play',
        builder: (_, s) => GameScreen(
          roomId: s.uri.queryParameters['room'],
          slug: s.uri.queryParameters['game'],
        ),
      ),
      // Keep old bookmarks and in-room game links working.
      GoRoute(
        path: Routes.games,
        builder: (_, state) => GamesCatalogScreen(
          roomId: state.uri.queryParameters['room'],
        ),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/friends', builder: (_, __) => const TingleFriendsScreen()),
      GoRoute(path: '/pk', builder: (_, __) => const PkBattlesScreen()),
      GoRoute(
          path: '/settings/blocked',
          builder: (_, __) => const TingleBlockedUsersScreen()),
      GoRoute(path: '/svip', redirect: (_, __) => Routes.profile),
      GoRoute(path: '/cp', builder: (_, __) => const CoupleRequestsScreen()),
      GoRoute(path: '/ranking', builder: (_, __) => const RankingScreen()),
      GoRoute(path: '/levels', builder: (_, __) => const LevelsScreen()),
      GoRoute(path: '/task', builder: (_, __) => const TingleTasksScreen()),
      GoRoute(
          path: '/daily-checkin',
          builder: (_, __) => const TingleDailyCheckinScreen()),
      GoRoute(path: '/game-level', builder: (_, __) => const GameLevelScreen()),
      GoRoute(
        path: '/store',
        builder: (_, state) => RoyalStoreScreen(
          initialBag: state.uri.queryParameters['bag'] == '1',
        ),
      ),
      GoRoute(
        path: '/social/:kind/:id',
        builder: (_, s) => SocialListScreen(
          kind: s.pathParameters['kind']!,
          userId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/info/:title',
        // Retired agency, host, BD, demo coin, medal and Honor Wall pages
        // are not navigable even from an older bookmark/deep link.
        redirect: (_, state) {
          const retired = {
            'host request', 'demo agency', 'demo host', 'demo bd',
            'agency', 'host', 'bd', 'demo coin', 'demo coins',
            'honor wall', 'medals', 'medal wall',
          };
          final name = state.pathParameters['title']?.trim().toLowerCase();
          return retired.contains(name) ? Routes.profile : null;
        },
        builder: (_, s) => s.pathParameters['title'] == 'Family'
            ? const FamilyScreen()
            : InfoScreen(title: s.pathParameters['title']!),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (_, s) => RoomScreen(roomId: s.pathParameters['id']!),
      ),
      GoRoute(
          path: Routes.wallet, builder: (_, __) => const TingleCoinsScreen()),
      GoRoute(
          path: '/wallet/exchange', builder: (_, __) => const WalletScreen()),
      GoRoute(
        path: Routes.discover,
        builder: (_, __) => const DiscoverScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.recharge,
        builder: (_, __) => const RechargeScreen(),
      ),
      GoRoute(path: Routes.vip, redirect: (_, __) => Routes.profile),
      GoRoute(
        path: '/profile/:id',
        builder: (_, s) => ProfileScreen(userId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) => ConversationScreen(otherId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/moments/create',
        builder: (_, __) => const CreateMomentScreen(),
      ),
      GoRoute(
        path: '/moments/:id/edit',
        builder: (_, s) => CreateMomentScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/moments/:id',
        builder: (_, s) => MomentDetailScreen(id: s.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, state) => HomeScreen(
                  initialTab:
                      int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.events,
                builder: (_, __) => const EventsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.moments,
                builder: (_, __) => const MomentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.messages,
                builder: (_, __) => const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, __) => const TingleMeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

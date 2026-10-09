import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_redirect.dart';
import '../features/social/social_screens.dart';
import '../features/discover/ranking_screen.dart';
import '../features/profile/levels_screen.dart';
import '../features/profile/profile_repository.dart';
import '../features/auth/presentation/update_password_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/forgot_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/verify_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/profile/me_screen.dart';
import '../features/games/game_screen.dart';
import '../features/games/game_level_screen.dart';
import '../features/store/store_screen.dart';
import '../features/games/games_catalog_screen.dart';
import '../features/rooms/presentation/create_room_screen.dart';
import '../features/rooms/presentation/room_settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/moments/moments_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/profile_setup_screen.dart';
import '../features/recharge/recharge_screen.dart';
import '../features/rooms/presentation/room_screen.dart';
import '../features/vip/vip_screen.dart';
import '../features/wallet/wallet_screen.dart';
import 'routes.dart';
import 'shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authStateProvider, (_, __) => refresh.refresh());
  ref.listen(passwordRecoveryProvider, (_, __) => refresh.refresh());
  final subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
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
          final profile = await ref.read(profileProvider(user.id).future);
          profileReady =
              (profile.displayName?.trim().isNotEmpty ?? false) &&
              profile.gender != null &&
              profile.dateOfBirth != null &&
              profile.countryCode != null;
        } catch (_) {
          profileReady = false;
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
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.register,
        builder: (_, __) => const RegisterScreen(),
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
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/svip', builder: (_, __) => const VipScreen(svip: true)),
      GoRoute(path: '/cp', builder: (_, __) => const CoupleRequestsScreen()),
      GoRoute(path: '/ranking', builder: (_, __) => const RankingScreen()),
      GoRoute(path: '/levels', builder: (_, __) => const LevelsScreen()),
      GoRoute(path: '/game-level', builder: (_, __) => const GameLevelScreen()),
      GoRoute(path: '/store', builder: (_, __) => const RoyalStoreScreen()),
      GoRoute(
        path: '/social/:kind/:id',
        builder: (_, s) => SocialListScreen(
          kind: s.pathParameters['kind']!,
          userId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/info/:title',
        builder: (_, s) => InfoScreen(title: s.pathParameters['title']!),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (_, s) => RoomScreen(roomId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.wallet, builder: (_, __) => const WalletScreen()),
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
      GoRoute(path: Routes.vip, builder: (_, __) => const VipScreen()),
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
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.games,
                builder: (_, s) =>
                    GamesCatalogScreen(roomId: s.uri.queryParameters['room']),
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
                builder: (_, __) => const MeScreen(),
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

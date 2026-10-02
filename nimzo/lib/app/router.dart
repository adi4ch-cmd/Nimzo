import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/forgot_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/verify_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/games/game_screen.dart';
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
import '../features/reseller/reseller_screen.dart';
import '../features/rooms/presentation/room_screen.dart';
import '../features/vip/vip_screen.dart';
import '../features/wallet/wallet_screen.dart';
import 'routes.dart';
import 'shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (ctx, state) {
      final loc = state.matchedLocation;
      if (auth.isLoading) return loc == Routes.splash ? null : Routes.splash;
      final user = auth.valueOrNull;
      final pub = {Routes.onboarding, Routes.login, Routes.register, Routes.forgot};
      if (user == null) {
        if (loc == Routes.splash) return Routes.onboarding;
        return pub.contains(loc) ? null : Routes.login;
      }
      if (!user.emailVerified) return loc == Routes.verify ? null : Routes.verify;
      if (loc == Routes.splash || pub.contains(loc) || loc == Routes.verify) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.forgot, builder: (_, __) => const ForgotScreen()),
      GoRoute(path: Routes.verify, builder: (_, __) => const VerifyScreen()),
      GoRoute(path: Routes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/create-room', builder: (_, __) => const CreateRoomScreen()),
      GoRoute(path: '/room/:id/settings', builder: (_, s) => RoomSettingsScreen(roomId: s.pathParameters['id']!, isOwner: s.uri.queryParameters['owner'] == 'true')),
      GoRoute(path: '/games-play', builder: (_, __) => const GameScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/room/:id', builder: (_, s) => RoomScreen(roomId: s.pathParameters['id']!)),
      GoRoute(path: Routes.wallet, builder: (_, __) => const WalletScreen()),
      GoRoute(path: Routes.discover, builder: (_, __) => const DiscoverScreen()),
      GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: Routes.reseller, builder: (_, __) => const ResellerScreen()),
      GoRoute(path: Routes.recharge, builder: (_, __) => const RechargeScreen()),
      GoRoute(path: Routes.vip, builder: (_, __) => const VipScreen()),
      GoRoute(path: '/profile/:id', builder: (_, s) => ProfileScreen(userId: s.pathParameters['id'])),
      GoRoute(path: '/chat/:id', builder: (_, s) => ConversationScreen(otherId: s.pathParameters['id']!)),
      GoRoute(path: '/moments/create', builder: (_, __) => const CreateMomentScreen()),
      GoRoute(path: '/moments/:id', builder: (_, s) => MomentDetailScreen(id: s.pathParameters['id']!)),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.games, builder: (_, __) => const GamesCatalogScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.moments, builder: (_, __) => const MomentsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.messages, builder: (_, __) => const MessagesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});

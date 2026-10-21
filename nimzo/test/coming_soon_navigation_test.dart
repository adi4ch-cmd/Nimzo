import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimzo/app/auth_redirect.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';
import 'package:nimzo/features/profile/tingle_me_screen.dart';

void main() {
  for (final path in ['/vip', '/svip']) {
    test('active premium destination $path is reachable by deep link', () {
      expect(
        authRedirect(
          location: path,
          user: const AuthUser(id: 'me', emailVerified: true),
          loading: false,
          recovering: false,
        ),
        isNull,
      );
    });
  }

  for (final path in ['/store', '/store?bag=1']) {
    test('active Store destination $path is no longer redirected', () {
      expect(
        authRedirect(
          location: path,
          user: const AuthUser(id: 'me', emailVerified: true),
          loading: false,
          recovering: false,
        ),
        isNull,
      );
    });
  }

  for (final label in ['My Store', 'Backpack', 'VIP', 'SVIP']) {
    testWidgets('profile $label opens its active destination',
        (tester) async {
      var opened = false;
      String? bagFromRoute;
      final router = GoRouter(initialLocation: '/profile', routes: [
        GoRoute(path: '/profile', builder: (_, __) => const TingleMeScreen()),
        GoRoute(path: '/vip',
            builder: (_, __) => const Scaffold(body: Text('VIP opened'))),
        GoRoute(path: '/svip',
            builder: (_, __) => const Scaffold(body: Text('SVIP opened'))),
        GoRoute(
          path: '/store',
          builder: (_, state) {
            opened = true;
            bagFromRoute = state.uri.queryParameters['bag'];
            return const Scaffold(body: Text('Store opened'));
          },
        ),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      for (var attempt = 0;
          attempt < 10 && find.text(label).hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(find.text(label).hitTestable(), findsOneWidget);
      await tester.tap(find.text(label).hitTestable());
      await tester.pumpAndSettle();

      if (label == 'VIP' || label == 'SVIP') {
        expect(find.text('$label opened'), findsOneWidget);
        expect(find.text('Coming soon'), findsNothing);
        expect(opened, isFalse);
      } else {
        expect(find.text('Store opened'), findsOneWidget);
        expect(find.text('Coming soon'), findsNothing);
        expect(opened, isTrue);
        // A push adds an imperative route on top of /profile; some GoRouter
        // versions keep the initial path in routeInformationProvider. The
        // rendered route and captured matched state are authoritative.
        expect(bagFromRoute, label == 'Backpack' ? '1' : isNull);
      }
    });
  }
}

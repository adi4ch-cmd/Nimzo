import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimzo/app/auth_redirect.dart';
import 'package:nimzo/app/routes.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';
import 'package:nimzo/features/profile/tingle_me_screen.dart';

void main() {
  for (final path in ['/vip', '/svip', '/store', '/store?bag=1', '/store/']) {
    test('disabled destination $path cannot be opened by deep link', () {
      expect(
          authRedirect(
              location: path,
              user: const AuthUser(id: 'me', emailVerified: true),
              loading: false,
              recovering: false),
          Routes.profile);
    });
  }
  for (final label in ['My Store', 'Backpack', 'VIP', 'SVIP']) {
    testWidgets('profile $label tap says Coming soon and keeps current page',
        (tester) async {
      var opened = false;
      final router = GoRouter(initialLocation: '/profile', routes: [
        GoRoute(path: '/profile', builder: (_, __) => const TingleMeScreen()),
        GoRoute(
            path: '/store',
            builder: (_, __) {
              opened = true;
              return const Scaffold(body: Text('Store opened'));
            }),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: MaterialApp.router(routerConfig: router)));
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
      expect(find.text('Coming soon'), findsOneWidget);
      expect(opened, isFalse);
      expect(router.routeInformationProvider.value.uri.path, '/profile');
    });
  }
}

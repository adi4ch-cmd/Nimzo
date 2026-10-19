import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:nimzo/app/router.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';
import 'package:nimzo/features/auth/presentation/auth_controller.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/tingle_membership_screen.dart';
import 'package:nimzo/features/profile/tingle_me_screen.dart';

void main() {
  test('stale server membership cannot restore retired identity', () {
    final p = Profile.fromJson({
      'id': 'u',
      'nimzo_id': 100001,
      'vip_level': 10,
      'vip_expires_at': '2099-01-01T00:00:00Z',
      'svip_level': 10,
      'svip_cycle_start': DateTime.now().toIso8601String()
    });
    expect(p.vipLevel, 0);
    expect(p.svipLevel, 0);
  });
  for (final path in ['/vip', '/svip']) {
    testWidgets('$path direct link cannot reopen a retired membership page',
        (tester) async {
      final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final container = ProviderContainer(overrides: [
        supabaseProvider.overrideWithValue(db),
        profileProvider('u').overrideWith((_) async => Profile(
              id: 'u',
              nimzoId: 100001,
              displayName: 'Nimzo User',
              gender: 'female',
              dateOfBirth: DateTime(2000),
              countryCode: 'PK',
            )),
        authStateProvider.overrideWith((_) => Stream.value(
              const AuthUser(id: 'u', emailVerified: true),
            )),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      final router = container.read(routerProvider);
      router.go(path);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TingleMembershipScreen), findsNothing);
      expect(find.byType(TingleMeScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

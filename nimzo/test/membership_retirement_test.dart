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
import 'package:nimzo/features/premium/willchill_premium_screen.dart';

void main() {
  test('server membership levels are real but expired VIP remains inactive', () {
    final p = Profile.fromJson({
      'id': 'u',
      'nimzo_id': 100001,
      'vip_level': 10,
      'vip_expires_at': '2099-01-01T00:00:00Z',
      'svip_level': 10,
      'svip_cycle_start': DateTime.now().toIso8601String(),
    });
    expect(p.vipLevel, 10);
    expect(p.svipLevel, 10);
    final expired = Profile.fromJson({
      'id': 'u',
      'nimzo_id': 100001,
      'vip_level': 7,
      'vip_expires_at': '2020-01-01T00:00:00Z',
    });
    expect(expired.vipLevel, 0);
  });

  for (final path in ['/vip', '/svip']) {
    testWidgets('$path opens a preview without granting any membership',
        (tester) async {
      final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final container = ProviderContainer(overrides: [
        supabaseProvider.overrideWithValue(db),
        profileProvider('u').overrideWith((_) async => const Profile(
              id: 'u', nimzoId: 100001, displayName: 'Nimzo User',
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
      final screen = tester.widget<WillChillPremiumScreen>(
          find.byType(WillChillPremiumScreen));
      expect(screen.initialGroup, path == '/vip' ? 'vip' : 'svip');
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

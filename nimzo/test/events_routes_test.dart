import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:nimzo/app/router.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';
import 'package:nimzo/features/auth/presentation/auth_controller.dart';
import 'package:nimzo/features/games/games_catalog_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

void main() {
  for (final room in <String?>[null, 'room-1']) {
    testWidgets('existing game link retains catalog and room $room',
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
      router.go(room == null ? '/games' : '/games?room=$room');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(GamesCatalogScreen), findsOneWidget);
      expect(
          tester
              .widget<GamesCatalogScreen>(find.byType(GamesCatalogScreen))
              .roomId,
          room);
      expect(router.routeInformationProvider.value.uri.path, '/games');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

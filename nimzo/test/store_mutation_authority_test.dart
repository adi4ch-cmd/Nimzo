import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';

void main() {
  for (final response in ['false', 'null']) {
    testWidgets('Store requires server confirmation ($response)',
        (tester) async {
      final client = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co',
            'test',
            httpClient: MockClient((request) async => http.Response(
                response, 200,
                request: request,
                headers: {'content-type': 'application/json'})),
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )))!;
      var reads = 0;
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionSupabaseProvider
            .overrideWithValue((client: client, userId: 'viewer')),
        nimzoStoreProvider.overrideWith((_) async {
          reads++;
          return const NimzoStoreSnapshot(items: [
            NimzoCosmeticItem(
              id: 'nimzo-original-avatar-frame-royal',
              category: 'Avatar Frame',
              name: 'Royal',
              variant: 0,
              coinPrice: 0,
            )
          ], owned: {}, equipped: {});
        }),
      ], child: const MaterialApp(home: NimzoLiveStore())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collect free'));
      await tester.pumpAndSettle();
      expect(find.textContaining('added to Backpack'), findsNothing);
      expect(find.textContaining('Unable to update Store'), findsOneWidget);
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(client.dispose);
    });
  }
}

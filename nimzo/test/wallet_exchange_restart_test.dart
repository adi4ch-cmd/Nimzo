import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'reopened wallet can recover an uncertain exchange with zero diamonds',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('/rpc/exchange_diamonds_checked'));
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return requests.length == 1
              ? http.Response('{"message":"response lost"}', 503,
                  request: request)
              : http.Response('{"status":"replayed","amount":100}', 200,
                  request: request,
                  headers: {'content-type': 'application/json'});
        }))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    Future<void> open(int diamonds) async {
      await tester.pumpWidget(ProviderScope(overrides: [
        supabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('account-a'),
        walletProvider
            .overrideWith((_) async => (coins: 1000, diamonds: diamonds))
      ], child: const MaterialApp(home: WalletScreen())));
      await tester.pumpAndSettle();
    }

    await open(100);
    await tester.enterText(
        find.byKey(const ValueKey('exchange-diamond-amount')), '100');
    await tester.tap(find.byKey(const ValueKey('exchange-diamonds-1-to-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Exchange'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await open(0);
    expect(find.text('Retry same exchange'), findsOneWidget);
    await tester.tap(find.text('Retry same exchange'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
    expect(requests[1]['p_expected_user'], 'account-a');
    expect(find.text('100 coins added.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

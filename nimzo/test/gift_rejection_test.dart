import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

void main() {
  testWidgets(
      'known gift rejection explains recovery and allows changing quantity',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async => http.Response(
              jsonEncode({
                'code': 'P0001',
                'message': 'insufficient coins',
                'details': 'private database detail',
                'hint': null,
              }),
              400,
              headers: {'content-type': 'application/json'},
              request: r)),
        )))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          giftRepositoryProvider.overrideWithValue(GiftRepository(db)),
          giftCatalogProvider.overrideWith((_) async => [
                const Gift('gift', 'Coffee', 'Classic', 500, null),
              ]),
          walletProvider.overrideWith((_) async => (coins: 10000, diamonds: 0)),
        ],
        child: const MaterialApp(
            home: Scaffold(body: GiftSheet(receiverId: 'receiver')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    expect(
        find.text('Not enough coins. Top up your wallet and retry this gift.'),
        findsOneWidget);
    expect(find.textContaining('private database detail'), findsNothing);
    expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .onChanged,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
}

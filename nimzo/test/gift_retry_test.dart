import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class UncertainGiftRepository extends GiftRepository {
  UncertainGiftRepository(super.db);
  final requests = <({String giftId, int qty, String key})>[];
  @override
  Future<void> sendProfile({
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
  }) async {
    requests.add((giftId: giftId, qty: qty, key: key));
    if (requests.length == 1) throw StateError('Response lost after send');
  }
}

void main() {
  testWidgets('uncertain gift retries preserve quantity and idempotency key', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = UncertainGiftRepository(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          giftRepositoryProvider.overrideWithValue(repo),
          giftCatalogProvider.overrideWith(
            (_) async => [const Gift('g', 'Coffee', 'Classic', 500, null)],
          ),
          walletProvider.overrideWith((_) async => (coins: 10000, diamonds: 0)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GiftSheet(receiverId: 'receiver')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee × 10 · 5000 coins'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    expect(repo.requests.single.qty, 10);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .onChanged,
      isNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    expect(repo.requests.length, 2);
    expect(repo.requests[1], repo.requests[0]);
    expect(tester.takeException(), isNull);
  });
}

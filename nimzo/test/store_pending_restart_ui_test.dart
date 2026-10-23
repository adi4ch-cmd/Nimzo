import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';
import 'package:nimzo/features/store/store_purchase_keys.dart';
import 'package:nimzo/features/store/store_purchase_repository.dart';

class ReceiptRepository extends NimzoStorePurchaseRepository {
  ReceiptRepository(super.db, this.preferences);
  final SharedPreferences preferences;
  Object? error;
  final attempts = <({String item, int price, String key})>[];
  @override
  Future<StorePurchaseResult> purchase(
      {required String itemId,
      required int expectedPrice,
      required String retryKey}) async {
    final saved = StorePurchaseKeys(preferences).read('sender')!;
    expect(saved.key, retryKey);
    expect(saved.expectedPrice, expectedPrice);
    attempts.add((item: itemId, price: expectedPrice, key: retryKey));
    if (error != null) throw error!;
    return StorePurchaseResult(status: 'replayed', total: expectedPrice);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'removed item retries original saved price after restart and isolates accounts',
      (tester) async {
    final client = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final prefs = await SharedPreferences.getInstance();
    const pending = PendingStorePurchase(
        accountId: 'sender',
        itemId: 'removed-frame',
        itemName: 'Golden Frame',
        expectedPrice: 250,
        key: '11111111111111111111111111111111',
        durationDays: 7);
    await StorePurchaseKeys(prefs).prepare(pending);
    final repository = ReceiptRepository(client, prefs)
      ..error = StateError('Lost response');
    Widget screen(String account) => ProviderScope(overrides: [
          sessionSupabaseProvider
              .overrideWithValue((client: client, userId: account)),
          nimzoStorePurchaseRepositoryProvider.overrideWithValue(repository),
          nimzoStoreProvider.overrideWith((_) async =>
              const NimzoStoreSnapshot(items: [], owned: {}, equipped: {})),
        ], child: const MaterialApp(home: NimzoLiveStore()));
    Future<void> retry() async {
      await tester.tap(find.byKey(const ValueKey('store-retry-purchase')));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('250 coins originally confirmed'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(screen('sender'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store-retry-purchase')), findsOneWidget);
    await retry();
    expect(repository.attempts.single,
        (item: 'removed-frame', price: 250, key: pending.key));
    expect(StorePurchaseKeys(prefs).read('sender')!.key, pending.key);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen('other-account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store-retry-purchase')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    repository.error = null;
    await tester.pumpWidget(screen('sender'));
    await tester.pumpAndSettle();
    await retry();
    expect(repository.attempts.length, 2);
    expect(repository.attempts[1], repository.attempts[0]);
    expect(StorePurchaseKeys(prefs).read('sender'), isNull);
    expect(find.byKey(const ValueKey('store-retry-purchase')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

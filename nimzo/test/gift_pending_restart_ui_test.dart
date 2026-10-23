import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_purchase_keys.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class RestartGiftRepository extends GiftRepository {
  RestartGiftRepository(super.db, this.preferences);
  final SharedPreferences preferences;
  final attempts =
      <({String receiver, String gift, int qty, String key, int? total})>[];
  @override
  Future<void> send(
      {required String roomId,
      required String receiverId,
      required String giftId,
      required int qty,
      required String key,
      int? expectedTotal}) async {
    final saved = GiftPurchaseKeys(preferences).read('sender', 'room:$roomId')!;
    expect(saved.key, key);
    expect(saved.expectedTotal, expectedTotal);
    attempts.add((
      receiver: receiverId,
      gift: giftId,
      qty: qty,
      key: key,
      total: expectedTotal
    ));
    throw StateError('Response still uncertain');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'reopened sheet retries removed gift at original amount, isolated from another account',
      (tester) async {
    final client = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final preferences = await SharedPreferences.getInstance();
    const pending = PendingGiftPurchase(
        accountId: 'sender',
        context: 'room:room',
        receiverId: 'original-recipient',
        giftId: 'removed-gift',
        giftName: 'Coffee',
        category: 'Classic',
        quantity: 10,
        expectedTotal: 5000,
        key: '11111111111111111111111111111111');
    await GiftPurchaseKeys(preferences).prepare(pending);
    final repository = RestartGiftRepository(client, preferences);
    Widget screen(String account) => ProviderScope(
            overrides: [
              supabaseProvider.overrideWithValue(client),
              currentUserIdProvider.overrideWithValue(account),
              giftRepositoryProvider.overrideWithValue(repository),
              giftCatalogProvider.overrideWith((_) async => []),
              walletProvider
                  .overrideWith((_) async => (coins: 10000, diamonds: 0)),
              roomSeatProfilesProvider('room').overrideWith((_) async => {}),
            ],
            child: const MaterialApp(
                home: Scaffold(
                    body: GiftSheet(
                        receiverId: 'new-recipient', roomId: 'room'))));
    await tester.pumpWidget(screen('sender'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('5000 coins originally confirmed'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .value,
        10);
    expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .onChanged,
        isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Coffee × 10 · 5000 coins'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(repository.attempts.single, (
      receiver: 'original-recipient',
      gift: 'removed-gift',
      qty: 10,
      key: pending.key,
      total: 5000
    ));
    expect(GiftPurchaseKeys(preferences).read('sender', 'room:room')!.key,
        pending.key);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen('different-account'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
    expect(
        find.textContaining('5000 coins originally confirmed'), findsNothing);
    expect(repository.attempts.length, 1);
    expect(tester.takeException(), isNull);
  });
}

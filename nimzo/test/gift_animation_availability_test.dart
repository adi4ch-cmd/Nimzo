import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/gifts/zodiac_gifts.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class UnavailableAnimatedGiftRepository extends GiftRepository {
  UnavailableAnimatedGiftRepository(super.db);
  int sends = 0;
  @override
  Future<String?> approvedAnimationUrl(String giftId) async => null;
  @override
  Future<void> sendProfile({
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
  }) async {
    sends++;
  }
}

void main() {
  testWidgets('unavailable promised animation is rejected before settlement', (
    tester,
  ) async {
    final db = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() => tester.runAsync(db.dispose));
    final repository = UnavailableAnimatedGiftRepository(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          giftRepositoryProvider.overrideWithValue(repository),
          giftCatalogProvider.overrideWith(
            (_) async => [
              const Gift(ariesGiftId, 'Aries', 'Premium', 500000, null),
            ],
          ),
          walletProvider.overrideWith(
            (_) async => (coins: 1000000, diamonds: 0),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GiftSheet(receiverId: 'receiver')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('gift-card-$ariesGiftId'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    expect(repository.sends, 0);
    expect(find.textContaining('No coins were charged.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

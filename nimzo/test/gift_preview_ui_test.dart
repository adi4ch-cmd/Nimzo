import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class PreviewRepository extends GiftRepository {
  PreviewRepository(super.db);
  int previewRequests = 0;
  int sends = 0;
  @override
  Future<GiftPlaybackMedia?> approvedAnimationMedia(String giftId) async {
    previewRequests++;
    return null;
  }

  @override
  Future<void> sendProfile(
      {required String receiverId,
      required String giftId,
      required int qty,
      required String key,
      int? expectedTotal}) async {
    sends++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('new live gift category and free preview never submit a purchase',
      (tester) async {
    final client = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final repository = PreviewRepository(client);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(client),
          currentUserIdProvider.overrideWithValue('sender'),
          giftRepositoryProvider.overrideWithValue(repository),
          giftCatalogProvider.overrideWith((_) async => [
                const Gift('new-gift', 'Spring Bouquet', 'Flowers', 250, null),
              ]),
          walletProvider.overrideWith((_) async => (coins: 1000, diamonds: 0)),
        ],
        child: const MaterialApp(
            home: Scaffold(
          body: GiftSheet(receiverId: 'receiver'),
        ))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Flowers'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Flowers'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Spring Bouquet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spring Bouquet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gift-preview-selected')));
    await tester.pumpAndSettle();
    expect(repository.previewRequests, 1);
    expect(repository.sends, 0);
    expect(find.text('Artwork preview'), findsOneWidget);
    expect(find.text('Animation preview is currently unavailable.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(repository.sends, 0);
    expect(tester.takeException(), isNull);
  });
}

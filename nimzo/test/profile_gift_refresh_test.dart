import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class SettledGiftRepository extends GiftRepository {
  SettledGiftRepository(super.db);
  @override
  Future<void> sendProfile({
    required String receiverId,
    required String giftId,
    required int qty,
    required String key,
  }) async {}
}

void main() {
  testWidgets('successful profile gift refreshes both cached profiles', (
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
    var senderLoads = 0, receiverLoads = 0, senderStats = 0, receiverStats = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('sender'),
          giftRepositoryProvider.overrideWithValue(SettledGiftRepository(db)),
          giftCatalogProvider.overrideWith(
            (_) async => [
              const Gift('gift', 'Test gift', 'Classic', 1000, null),
            ],
          ),
          walletProvider.overrideWith((_) async => (coins: 10000, diamonds: 0)),
          profileStatsProvider('sender').overrideWith((_) async {
            senderStats++;
            return {};
          }),
          profileStatsProvider('receiver').overrideWith((_) async {
            receiverStats++;
            return {};
          }),
          profileProvider('sender').overrideWith((_) async {
            senderLoads++;
            return const Profile(id: 'sender', nimzoId: 1);
          }),
          profileProvider('receiver').overrideWith((_) async {
            receiverLoads++;
            return const Profile(id: 'receiver', nimzoId: 2);
          }),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(profileStatsProvider('sender'));
              ref.watch(profileStatsProvider('receiver'));
              ref.watch(profileProvider('sender'));
              ref.watch(profileProvider('receiver'));
              return Scaffold(
                body: TextButton(
                  onPressed: () => showProfileGiftSheet(context, 'receiver'),
                  child: const Text('Open gift sheet'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(senderLoads, 1);
    expect(receiverLoads, 1);
    await tester.tap(find.text('Open gift sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test gift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    expect(senderLoads, 2);
    expect(receiverLoads, 2);
    expect(senderStats, 2);
    expect(receiverStats, 2);
    expect(tester.takeException(), isNull);
  });
}

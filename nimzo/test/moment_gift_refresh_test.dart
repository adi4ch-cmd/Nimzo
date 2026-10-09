import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class SettledMomentGiftRepository extends MomentRepository {
  SettledMomentGiftRepository(super.db);
  @override
  Future<void> sendGift(
      {required String momentId,
      required String receiverId,
      required String giftId,
      required int qty,
      required String key}) async {}
}

void main() {
  testWidgets('Moment gift refreshes detail and author Moments caches',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final moment = Moment(
        id: 'moment',
        authorId: 'author',
        likes: 0,
        comments: 0,
        liked: false,
        createdAt: DateTime(2026));
    var detailLoads = 0, authorLoads = 0;
    final container = ProviderContainer(overrides: [
      supabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(null),
      momentRepositoryProvider
          .overrideWithValue(SettledMomentGiftRepository(db)),
      giftCatalogProvider.overrideWith((_) async => [
            const Gift('gift', 'Coffee', 'Classic', 500, null),
          ]),
      walletProvider.overrideWith((_) async => (coins: 10000, diamonds: 0)),
      momentsFeedProvider.overrideWith((_) async => [moment]),
      momentDetailProvider('moment').overrideWith((_) async {
        detailLoads++;
        return moment;
      }),
      profileMomentsProvider('author').overrideWith((_) async {
        authorLoads++;
        return [moment];
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(momentDetailProvider('moment').future);
    await container.read(profileMomentsProvider('author').future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(
                body: GiftSheet(
          receiverId: 'author',
          momentId: 'moment',
        )))));
    await tester.pumpAndSettle();
    // Tap the actual gift card, not the label which can be obscured by
    // the fixed quantity/send tray on smaller viewports.
    final coffeeCard = find.ancestor(
        of: find.text('Coffee'), matching: find.byType(InkWell));
    expect(coffeeCard, findsWidgets);
    await tester.ensureVisible(coffeeCard.first);
    await tester.tap(coffeeCard.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
    await tester.pumpAndSettle();
    await container.read(momentDetailProvider('moment').future);
    await container.read(profileMomentsProvider('author').future);
    expect(detailLoads, 2);
    expect(authorLoads, 2);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/settings/honor_wall_content.dart';
import 'package:nimzo/features/store/store_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeStore extends RoyalStoreRepository {
  _FakeStore(super.db);

  String? equippedId;

  @override
  Future<void> equip(String itemId) async {
    equippedId = itemId;
  }
}

void main() {
  const medal = RoyalBagItem(
    id: 'medal-1',
    name: 'Royal Crest I',
    image: 'assets/hilo/store/royal_1.webp',
    equipped: false,
  );
  const shopItem = RoyalStoreItem(
    id: 'medal-1',
    name: 'Royal Crest I',
    image: 'assets/hilo/store/royal_1.webp',
    description: 'Royal collectible',
    price: 10000,
  );

  testWidgets('Honor Wall requires an account, not fake medal previews',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue(null)],
      child: const MaterialApp(home: Scaffold(body: HonorWallContent())),
    ));
    expect(find.text('Sign in to view your medals.'), findsOneWidget);
    expect(find.text('Room medal previews'), findsNothing);
  });

  testWidgets('real owned and store medals render without phantom awards',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('u'),
        royalBagProvider('u').overrideWith((_) async => [medal]),
        royalCatalogProvider.overrideWith((_) async => [shopItem]),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HonorWallContent()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('NIMZO MEDALS'), findsOneWidget);
    expect(find.text('1 owned · None equipped'), findsOneWidget);
    expect(find.text('Royal Crest I'), findsNWidgets(2));
    expect(find.text('Equip'), findsOneWidget);
    expect(find.text('Owned'), findsOneWidget);
    expect(find.text('Room medal previews'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equip uses existing verified store RPC service',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final store = _FakeStore(db);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('u'),
        royalBagProvider('u').overrideWith((_) async => [medal]),
        royalCatalogProvider.overrideWith((_) async => [shopItem]),
        royalStoreRepositoryProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HonorWallContent()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equip'));
    await tester.pumpAndSettle();
    expect(store.equippedId, 'medal-1');
    expect(
      find.text('Medal equipped on your NIMZO profile.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

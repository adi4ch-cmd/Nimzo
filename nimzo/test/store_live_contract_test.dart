import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<String> _source(String path) => File(path).readAsString();

void main() {
  test('Store and Backpack deep links no longer show Coming soon', () async {
    final availability = await _source('lib/app/feature_availability.dart');
    final router = await _source('lib/app/router.dart');
    final screen = await _source('lib/features/store/store_screen.dart');
    expect(availability, isNot(contains("'/vip', '/svip', '/store'")));
    expect(router, contains("path: '/store',"));
    expect(router, contains("state.uri.queryParameters['bag'] == '1'"));
    expect(screen, contains('NimzoLiveStore(initialBag: initialBag)'));
  });

  test('Real store uses verified original catalog without fake checkout', () async {
    final live = await _source('lib/features/store/store_live_catalog.dart');
    final migration = await _source(
      '../supabase/migrations/'
      '20261020000500_activate_original_cosmetics_store.sql',
    );
    expect(live, contains("from('nimzo_cosmetic_catalog')"));
    expect(live, contains("from('nimzo_cosmetic_ownership')"));
    expect(live, contains("from('nimzo_cosmetic_equipped')"));
    expect(live, contains("'nimzo_store_claim_free'"));
    expect(live, contains("'nimzo_store_equip_free'"));
    expect(live, contains('Not for sale'));
    expect(migration, contains('references auth.users(id)'));
    expect(migration, contains('on conflict (user_id,item_id) do nothing'));
    expect(migration, contains('coin_price=0'));
    expect(migration, isNot(contains('update public.wallets')));
    expect(migration, isNot(contains('delete from public.ledger')));
    expect(migration, isNot(contains('purchase_normal_vip')));
    expect(migration, isNot(contains('nimzo_store_buy')));
  });
}

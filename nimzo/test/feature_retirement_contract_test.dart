import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<String> source(String file) => File(file).readAsString();

void main() {
  test('Me screen hides obsolete demo roles and QR entry', () async {
    final me = await source('lib/features/profile/tingle_me_screen.dart');
    for (final old in [
      'Host Request', 'Demo Agency', 'Demo Host', 'Demo BD',
      'Demo Coin', 'My QR / profile', 'qr_code_2_rounded',
    ]) {
      expect(me, isNot(contains(old)), reason: old);
    }
    expect(me, isNot(contains("title: 'Coin Trading'")));
    expect(me, contains("title: 'Help'"));
  });

  test('Coin screen does not fetch or display financial ledger history', () async {
    final coins = await source('lib/features/wallet/tingle_coins_screen.dart');
    expect(coins, isNot(contains('Coin History')));
    expect(coins, isNot(contains("from('ledger')")));
    expect(coins, isNot(contains('tingleCoinHistoryProvider')));
    expect(coins, contains('Remaining coins'));
    expect(coins, contains('Diamonds and 1:1 exchange'));
  });

  test('Old gift history, medals and premium gift previews are removed',
      () async {
    final profile = await source('lib/features/profile/profile_screen.dart');
    final data = await source('lib/features/profile/profile_repository.dart');
    final oldMe = await source('lib/features/profile/me_screen.dart');
    final room = await source('lib/features/rooms/presentation/room_screen.dart');
    final mini = await source(
        'lib/features/rooms/presentation/room_user_sheet.dart');
    final collection = await source('lib/features/profile/profile_collections.dart');
    final store = await source('lib/features/store/store_screen.dart');
    final gifts = await source('lib/features/gifts/gift_sheet.dart');
    for (final s in [profile, data, oldMe, room, mini]) {
      expect(s, isNot(contains('EquippedRoyalMedal')));
    }
    expect(profile, isNot(contains('GiftList')));
    expect(profile, isNot(contains('Medal Wall')));
    expect(data, isNot(contains("'profile_gifts'")));
    expect(room, isNot(contains('room-header-total-gifting')));
    expect(oldMe, isNot(contains('1M+ Gift Live Ranking')));
    expect(collection, contains('enum ProfileCollection { frame, car }'));
    expect(store, isNot(contains("'Medals'")));
    expect(store, isNot(contains('nimzo_store_buy')));
    expect(gifts, isNot(contains('NewGiftPreviewCollection')));
    expect(gifts, contains("'Cars'"));
  });

  test('SQL disables all but Sports Car and removes medal entitlements '
       'without deleting wallets/ledger', () async {
    final migration = await source(
      '../supabase/migrations/'
      '20261018213000_retire_noncar_gifts_medals_history_access.sql');
    expect(migration, contains("lower(trim(name))='sports car'"));
    expect(migration, contains('set active=(id=v_car)'));
    expect(migration, contains('delete from public.profile_owned_collectibles'));
    expect(migration, contains('revoke execute on function public.nimzo_store_buy'));
    expect(migration, contains('revoke execute on function public.profile_gifts'));
    expect(migration.toLowerCase(), isNot(contains('delete from public.ledger')));
    expect(migration.toLowerCase(), isNot(contains('truncate public.ledger')));
  });
}

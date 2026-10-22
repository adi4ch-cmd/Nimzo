import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimzo/features/gifts/gift_purchase_keys.dart';

PendingGiftPurchase request(
        {String account = 'sender',
        String context = 'room:one',
        String receiver = 'receiver',
        String key = '11111111111111111111111111111111',
        int total = 5000}) =>
    PendingGiftPurchase(
        accountId: account,
        context: context,
        receiverId: receiver,
        giftId: 'gift',
        giftName: 'Coffee',
        category: 'Classic',
        quantity: 10,
        expectedTotal: total,
        key: key);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restart restores exact confirmed amount, key, recipient and quantity',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await GiftPurchaseKeys(preferences).prepare(request());
    final restored = GiftPurchaseKeys(preferences).read('sender', 'room:one')!;
    expect(restored.toJson(), request().toJson());
    await GiftPurchaseKeys(preferences).prepare(restored);
    expect(preferences.getKeys().length, 1);
  });

  test('account, room, Moment and profile receipts are isolated', () async {
    final store = GiftPurchaseKeys(await SharedPreferences.getInstance());
    await store.prepare(request());
    expect(store.read('other-account', 'room:one'), isNull);
    expect(store.read('sender', 'room:two'), isNull);
    expect(store.read('sender', 'moment:one'), isNull);
    expect(store.read('sender', 'profile:receiver'), isNull);
    await store.prepare(request(account: 'other-account', total: 9000));
    expect(store.read('sender', 'room:one')!.expectedTotal, 5000);
    expect(store.read('other-account', 'room:one')!.expectedTotal, 9000);
  });

  test(
      'uncertain receipt cannot be overwritten with another payload or cleared by another key',
      () async {
    final store = GiftPurchaseKeys(await SharedPreferences.getInstance());
    await store.prepare(request());
    await expectLater(
        store.prepare(request(receiver: 'other')), throwsStateError);
    await expectLater(store.prepare(request(total: 6000)), throwsStateError);
    await store.complete(request(key: '22222222222222222222222222222222'));
    expect(store.read('sender', 'room:one'), isNotNull);
    await store.complete(request());
    expect(store.read('sender', 'room:one'), isNull);
  });

  test('concurrent sheets cannot persist different keys for the same receipt',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = GiftPurchaseKeys(prefs).prepare(request());
    final second = GiftPurchaseKeys(prefs)
        .prepare(request(key: '22222222222222222222222222222222'));
    final rejected = expectLater(second, throwsStateError);
    await first;
    await rejected;
    expect(
        GiftPurchaseKeys(prefs).read('sender', 'room:one')!.key, request().key);
  });

  test('corrupt stored receipt fails closed instead of permitting a new debit',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final store = GiftPurchaseKeys(prefs);
    await store.prepare(request());
    await prefs.setString(prefs.getKeys().single, '{broken');
    expect(() => store.read('sender', 'room:one'), throwsFormatException);
    await expectLater(store.prepare(request()), throwsFormatException);
  });
}

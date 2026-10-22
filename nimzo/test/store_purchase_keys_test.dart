import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimzo/features/store/store_purchase_keys.dart';

PendingStorePurchase request(
        {String account = 'sender',
        String item = 'frame-one',
        int price = 250,
        String key = '11111111111111111111111111111111'}) =>
    PendingStorePurchase(
        accountId: account,
        itemId: item,
        itemName: 'Golden Frame',
        expectedPrice: price,
        key: key,
        durationDays: 7);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'restart preserves original item price duration and key scoped to account',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await StorePurchaseKeys(prefs).prepare(request());
    final restarted = StorePurchaseKeys(prefs);
    expect(restarted.read('sender')!.toJson(), request().toJson());
    expect(restarted.read('other'), isNull);
    await restarted.prepare(request(account: 'other', price: 500));
    expect(restarted.read('sender')!.expectedPrice, 250);
  });
  test('unknown purchase cannot be overwritten or cleared with another key',
      () async {
    final store = StorePurchaseKeys(await SharedPreferences.getInstance());
    await store.prepare(request());
    await expectLater(store.prepare(request(price: 500)), throwsStateError);
    await expectLater(
        store.prepare(request(item: 'frame-two')), throwsStateError);
    await store.complete(request(key: '22222222222222222222222222222222'));
    expect(store.read('sender'), isNotNull);
    await store.complete(request());
    expect(store.read('sender'), isNull);
  });
  test('competing sheets persist only one key for an account', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = StorePurchaseKeys(prefs).prepare(request());
    final second = StorePurchaseKeys(prefs)
        .prepare(request(key: '22222222222222222222222222222222'));
    final rejected = expectLater(second, throwsStateError);
    await first;
    await rejected;
    expect(StorePurchaseKeys(prefs).read('sender')!.key, request().key);
  });
  test('corrupt saved receipt blocks replacement rather than losing its key',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final store = StorePurchaseKeys(prefs);
    await store.prepare(request());
    await prefs.setString(prefs.getKeys().single, '{broken');
    expect(() => store.read('sender'), throwsFormatException);
    await expectLater(store.prepare(request()), throwsFormatException);
  });
}

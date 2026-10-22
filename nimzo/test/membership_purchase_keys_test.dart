import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimzo/features/premium/membership_purchase_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('reopening restores account and tier bound purchase until confirmed',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final original = await MembershipPurchaseKeys(preferences).prepare('a', 10);
    final restarted = MembershipPurchaseKeys(preferences);
    expect(await restarted.prepare('a', 10), original);
    expect(await restarted.prepare('b', 10), isNot(original));
    expect(await restarted.prepare('a', 9), isNot(original));
    await restarted.complete('a', 10, 'unrelated-old-response');
    expect(await restarted.prepare('a', 10), original);
    await restarted.complete('a', 10, original);
    expect(await restarted.prepare('a', 10), isNot(original));
  });
  test(
      'reopened retries retain the original confirmed price after price changes',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final keys = MembershipPurchaseKeys(preferences);
    final first = await keys.prepareWithPrice('a', 1, 1000);
    final restarted = MembershipPurchaseKeys(preferences);
    expect(await restarted.prepareWithPrice('a', 1, 2000), first);
    expect(restarted.pendingPrice('a', 1), 1000);
    await restarted.complete('a', 1, first);
    expect(restarted.pendingPrice('a', 1), isNull);
    await restarted.prepareWithPrice('a', 1, 2000);
    expect(restarted.pendingPrice('a', 1), 2000);
  });

  test('competing membership confirmations retain one immutable key and price',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final keys = MembershipPurchaseKeys(preferences);
    final results = await Future.wait([
      keys.prepareWithPrice('a', 1, 1000),
      MembershipPurchaseKeys(preferences).prepareWithPrice('a', 1, 2000),
    ]);
    expect(results.toSet().length, 1);
    expect(keys.pendingPrice('a', 1), 1000);
  });
}

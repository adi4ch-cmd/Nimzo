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
}

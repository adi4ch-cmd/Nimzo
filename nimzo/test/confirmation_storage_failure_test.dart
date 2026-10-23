import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:nimzo/features/wallet/diamond_exchange_session.dart';

class FailingWrites extends InMemorySharedPreferencesStore {
  FailingWrites() : super.empty();
  int writes = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes++;
    if (writes <= 2) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  test('a matching cache after failed saves cannot authorize an exchange',
      () async {
    SharedPreferences.resetStatic();
    final previous = SharedPreferencesStorePlatform.instance;
    final store = FailingWrites();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    final session = DiamondExchangeSession('account-a');
    var submissions = 0;
    Future<Map<String, dynamic>> submit(Map<String, dynamic> params) async {
      submissions++;
      return {'status': 'exchanged', 'amount': params['p_amount']};
    }

    await expectLater(session.submit(100, submit), throwsStateError);
    await expectLater(session.submit(100, submit), throwsStateError);
    expect(submissions, 0);
    expect(store.writes, 2);
    await session.submit(100, submit);
    expect(submissions, 1);
    expect(store.writes, 3);
  });
}

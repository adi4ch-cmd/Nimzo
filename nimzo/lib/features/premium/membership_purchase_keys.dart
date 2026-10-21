import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Save before sending; a reopened membership page retries the same purchase.
class MembershipPurchaseKeys {
  MembershipPurchaseKeys(this.preferences);
  final SharedPreferences preferences;
  String _name(String account, int tier) =>
      'nimzo.pending-vip.v1.$account.$tier';

  Future<String> prepare(String account, int tier) async {
    final name = _name(account, tier);
    final previous = preferences.getString(name);
    if (previous != null) {
      if (previous.length < 8 || previous.length > 128)
        throw const FormatException('Invalid pending VIP purchase');
      return previous;
    }
    final key =
        base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)));
    if (!await preferences.setString(name, key))
      throw StateError('Purchase must be saved before spending coins');
    return key;
  }

  Future<void> complete(String account, int tier, String key) async {
    final name = _name(account, tier);
    if (preferences.getString(name) == key && !await preferences.remove(name)) {
      throw StateError('Purchase receipt could not be saved');
    }
  }
}

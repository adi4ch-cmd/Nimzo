import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Save before sending; a reopened membership page retries the same purchase.
class MembershipPurchaseKeys {
  MembershipPurchaseKeys(this.preferences);
  final SharedPreferences preferences;
  static Completer<void>? _activeWrite;
  Future<T> _serialized<T>(Future<T> Function() operation) async {
    while (_activeWrite != null) {
      await _activeWrite!.future;
    }
    final active = Completer<void>();
    _activeWrite = active;
    try {
      return await operation();
    } finally {
      if (identical(_activeWrite, active)) _activeWrite = null;
      active.complete();
    }
  }

  String _name(String account, int tier) =>
      'nimzo.pending-vip.v1.$account.$tier';

  Future<String> prepare(String account, int tier) =>
      _serialized(() => _prepare(account, tier));

  Future<String> _prepare(String account, int tier) async {
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

  int? pendingPrice(String account, int tier) =>
      preferences.getInt('${_name(account, tier)}.coins');

  Future<String> prepareWithPrice(
          String account, int tier, int confirmedCoins) =>
      _serialized(() async {
        if (confirmedCoins < 1)
          throw const FormatException('Invalid confirmed price');
        final name = _name(account, tier);
        final previous = preferences.getString(name);
        if (previous == null || pendingPrice(account, tier) == null) {
          if (!await preferences.setInt('$name.coins', confirmedCoins)) {
            throw StateError(
                'Purchase price must be saved before spending coins');
          }
        }
        return _prepare(account, tier);
      });

  Future<void> complete(String account, int tier, String key) =>
      _serialized(() async {
        final name = _name(account, tier);
        if (preferences.getString(name) == key) {
          if (!await preferences.remove(name))
            throw StateError('Purchase receipt could not be saved');
          await preferences.remove('$name.coins');
        }
      });
}

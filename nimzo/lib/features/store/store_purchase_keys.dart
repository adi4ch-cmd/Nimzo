import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// The exact account/item/price the owner confirmed, never a grant or balance.
class PendingStorePurchase {
  const PendingStorePurchase(
      {required this.accountId,
      required this.itemId,
      required this.itemName,
      required this.expectedPrice,
      required this.key,
      this.durationDays});
  final String accountId, itemId, itemName, key;
  final int expectedPrice;
  final int? durationDays;
  static String newKey() => List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
  Map<String, Object?> toJson() => {
        'account': accountId,
        'item': itemId,
        'name': itemName,
        'price': expectedPrice,
        'key': key,
        'days': durationDays
      };
  factory PendingStorePurchase.fromJson(Map<String, dynamic> data) {
    for (final field in ['account', 'item', 'name', 'key']) {
      if (data[field] is! String ||
          (data[field] as String).isEmpty ||
          (data[field] as String).length > 512) {
        throw const FormatException('Invalid saved Store receipt');
      }
    }
    final price = data['price'], days = data['days'];
    if ((data['item'] as String).length < 5 ||
        (data['item'] as String).length > 100 ||
        price is! int ||
        price < 1 ||
        price > 1000000000000 ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(data['key'] as String) ||
        (days != null && (days is! int || days < 1 || days > 3650))) {
      throw const FormatException('Invalid saved Store confirmation');
    }
    return PendingStorePurchase(
        accountId: data['account'] as String,
        itemId: data['item'] as String,
        itemName: data['name'] as String,
        expectedPrice: price,
        key: data['key'] as String,
        durationDays: days as int?);
  }
}

class StorePurchaseKeys {
  StorePurchaseKeys(this.preferences);
  final SharedPreferences preferences;
  static Future<void>? _active;
  Future<void> _serialized(Future<void> Function() action) async {
    while (_active != null) {
      await _active;
    }
    final done = Completer<void>();
    _active = done.future;
    try {
      await action();
    } finally {
      _active = null;
      done.complete();
    }
  }

  String _name(String account) =>
      'nimzo.pending-store.v1.${base64Url.encode(utf8.encode(account))}';
  PendingStorePurchase? read(String account) {
    final raw = preferences.getString(_name(account));
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved Store receipt');
    }
    final pending = PendingStorePurchase.fromJson(data);
    if (pending.accountId != account) {
      throw const FormatException('Saved Store account mismatch');
    }
    return pending;
  }

  Future<void> prepare(PendingStorePurchase request) => _serialized(() async {
        PendingStorePurchase.fromJson(request.toJson());
        final previous = read(request.accountId);
        final raw = jsonEncode(request.toJson());
        if (previous != null && jsonEncode(previous.toJson()) != raw) {
          throw StateError(
              'Resolve your saved Store purchase before buying another item.');
        }
        if (previous == null &&
            !await preferences.setString(_name(request.accountId), raw)) {
          throw StateError('Store confirmation must be saved before charging.');
        }
      });
  Future<void> complete(PendingStorePurchase request) => _serialized(() async {
        if (read(request.accountId)?.key == request.key &&
            !await preferences.remove(_name(request.accountId))) {
          throw StateError('Store receipt could not be saved.');
        }
      });
}

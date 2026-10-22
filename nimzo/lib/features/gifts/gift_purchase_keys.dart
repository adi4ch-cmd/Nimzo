import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// An immutable confirmation, retained until settlement or a known rollback.
/// Local data never grants a debit: the server verifies identity and total.
class PendingGiftPurchase {
  const PendingGiftPurchase(
      {required this.accountId,
      required this.context,
      required this.receiverId,
      required this.giftId,
      required this.giftName,
      required this.category,
      required this.quantity,
      required this.expectedTotal,
      required this.key,
      this.assetPath});

  final String accountId, context, receiverId, giftId, giftName, category, key;
  final String? assetPath;
  final int quantity, expectedTotal;

  static String newKey() => List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();

  Map<String, Object?> toJson() => {
        'account': accountId,
        'context': context,
        'receiver': receiverId,
        'gift': giftId,
        'name': giftName,
        'category': category,
        'asset': assetPath,
        'quantity': quantity,
        'total': expectedTotal,
        'key': key,
      };

  factory PendingGiftPurchase.fromJson(Map<String, dynamic> json) {
    for (final field in [
      'account',
      'context',
      'receiver',
      'gift',
      'name',
      'category',
      'key'
    ]) {
      if (json[field] is! String ||
          (json[field] as String).isEmpty ||
          (json[field] as String).length > 512) {
        throw const FormatException('Invalid pending gift');
      }
    }
    final quantity = json['quantity'], total = json['total'];
    if (quantity is! int ||
        !const {1, 10, 50, 99, 100, 999}.contains(quantity) ||
        total is! int ||
        total < 0 ||
        total > 1000000000000 ||
        total % quantity != 0 ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(json['key'] as String) ||
        (json['asset'] != null &&
            (json['asset'] is! String ||
                (json['asset'] as String).length > 2048))) {
      throw const FormatException('Invalid pending gift confirmation');
    }
    return PendingGiftPurchase(
        accountId: json['account'] as String,
        context: json['context'] as String,
        receiverId: json['receiver'] as String,
        giftId: json['gift'] as String,
        giftName: json['name'] as String,
        category: json['category'] as String,
        quantity: quantity,
        expectedTotal: total,
        key: json['key'] as String,
        assetPath: json['asset'] as String?);
  }
}

class GiftPurchaseKeys {
  GiftPurchaseKeys(this.preferences);
  final SharedPreferences preferences;
  // Keep only active work. Retaining a completed Future also retains its
  // original zone, which can strand callbacks when a widget test/app scope ends.
  static Future<void>? _activeWrite;
  Future<void> _serialized(Future<void> Function() action) async {
    while (_activeWrite != null) {
      await _activeWrite;
    }
    final finished = Completer<void>();
    _activeWrite = finished.future;
    try {
      await action();
    } finally {
      _activeWrite = null;
      finished.complete();
    }
  }

  String _name(String account, String context) =>
      'nimzo.pending-gift.v1.${base64Url.encode(utf8.encode(account))}.'
      '${base64Url.encode(utf8.encode(context))}';

  PendingGiftPurchase? read(String account, String context) {
    final raw = preferences.getString(_name(account, context));
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Pending gift receipt unavailable');
    }
    final pending = PendingGiftPurchase.fromJson(value);
    if (pending.accountId != account || pending.context != context) {
      throw const FormatException('Pending gift account mismatch');
    }
    return pending;
  }

  Future<void> prepare(PendingGiftPurchase request) => _serialized(() async {
        PendingGiftPurchase.fromJson(request.toJson());
        final existing = read(request.accountId, request.context);
        final encoded = jsonEncode(request.toJson());
        if (existing != null && jsonEncode(existing.toJson()) != encoded) {
          throw StateError(
              'Resolve the existing gift receipt before sending another gift');
        }
        if (existing == null &&
            !await preferences.setString(
                _name(request.accountId, request.context), encoded)) {
          throw StateError('Gift confirmation must be saved before sending');
        }
      });

  Future<void> complete(PendingGiftPurchase request) => _serialized(() async {
        final existing = read(request.accountId, request.context);
        if (existing?.key == request.key &&
            !await preferences
                .remove(_name(request.accountId, request.context))) {
          throw StateError('Gift receipt could not be saved');
        }
      });
}

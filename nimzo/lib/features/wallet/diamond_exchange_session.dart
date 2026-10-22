import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/storage/pending_confirmation_store.dart';

/// Keep the original confirmation until its exact settlement is known.
class DiamondExchangeSession {
  DiamondExchangeSession(this.account);
  final String account;
  String get storageKey =>
      'nimzo.pending-exchange.v1.${base64UrlEncode(utf8.encode(account))}';
  int? _amount;
  String? _key;
  int? _attempt;
  String get _encoded =>
      jsonEncode({'account': account, 'amount': _amount, 'key': _key});
  bool _restored = false, _busy = false;
  int? get pendingAmount => _amount;
  Future<void> restore() async {
    if (_restored) return;
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw != null) {
      if (raw.length > 1024)
        throw const FormatException('Invalid exchange confirmation');
      final p = jsonDecode(raw);
      if (p is! Map ||
          p['account'] != account ||
          p['amount'] is! int ||
          p['amount'] <= 0 ||
          p['key'] is! String ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(p['key']))
        throw const FormatException('Invalid exchange confirmation');
      _amount = p['amount'] as int;
      _key = p['key'] as String;
    }
    _restored = true;
  }

  Future<void> _clear() async {
    await PendingConfirmationStore.complete(storageKey, _encoded, _attempt!);
    _amount = null;
    _key = null;
  }

  Future<void> submit(
      int amount,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)
          exchange) async {
    if (_busy) throw StateError('Exchange already submitting');
    _busy = true;
    try {
      await restore();
      if (_amount == null) {
        if (amount <= 0) throw ArgumentError('Invalid exchange amount');
        _amount = amount;
        _key = List.generate(
            24,
            (_) => Random.secure()
                .nextInt(256)
                .toRadixString(16)
                .padLeft(2, '0')).join();
      }
      _attempt = await PendingConfirmationStore.prepare(storageKey, _encoded);
      final result = await exchange(
          {'p_amount': _amount, 'p_key': _key, 'p_expected_user': account});
      if (result['amount'] != _amount ||
          !{'exchanged', 'replayed'}.contains(result['status']))
        throw StateError('Exchange unconfirmed');
      await _clear();
    } on PostgrestException catch (e) {
      if (e.code == 'P0001' && e.message == 'insufficient diamonds')
        await _clear();
      rethrow;
    } finally {
      _busy = false;
    }
  }
}

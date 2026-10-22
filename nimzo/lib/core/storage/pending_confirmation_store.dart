import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Serializes short local writes, never network requests. Each attempt owns a
/// lease: an older response cannot clear a newer attempt, even for the same key.
abstract final class PendingConfirmationStore {
  static Future<void>? _active;
  static int _nextAttempt = 0;
  static final Map<String, int> _latestAttempt = {};

  static Future<T> _serialized<T>(
      Future<T> Function(SharedPreferences) action) async {
    while (_active != null) {
      await _active;
    }
    final done = Completer<void>();
    _active = done.future;
    try {
      return await action(await SharedPreferences.getInstance());
    } finally {
      _active = null;
      done.complete();
    }
  }

  static Future<int> prepare(String name, String encoded) =>
      _serialized((prefs) async {
        final previous = prefs.getString(name);
        if (previous != null && previous != encoded)
          throw StateError(
              'A newer confirmation is pending. Reopen this screen to recover it.');
        // SharedPreferences updates its cache before the platform write. A
        // matching cache is not proof that an earlier write reached storage.
        if (!await prefs.setString(name, encoded))
          throw StateError('Confirmation must be saved before submission');
        final lease = ++_nextAttempt;
        _latestAttempt[name] = lease;
        return lease;
      });
  static Future<void> complete(String name, String encoded, int lease) =>
      _serialized((prefs) async {
        if (_latestAttempt[name] != lease) return;
        if (prefs.getString(name) == encoded) {
          if (!await prefs.remove(name))
            throw StateError('Confirmed receipt could not be saved');
          _latestAttempt.remove(name);
        }
      });
}

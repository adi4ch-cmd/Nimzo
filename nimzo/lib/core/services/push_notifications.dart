import 'dart:async';

abstract interface class PushGateway {
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get tokenRefresh;
  Stream<Map<String, dynamic>> get opened;
  Future<Map<String, dynamic>?> initialMessage();
}

String? pushNotificationId(Map<String, dynamic> data, String? user) {
  final id = data['notification_id'];
  if (user == null || data['user_id'] != user || id is! String) return null;
  return RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id)
      ? id
      : null;
}

/// FCM carries an identity only. The database authorizes the opened activity.
class PushNotifications {
  PushNotifications(
      {required this.gateway, required this.register, required this.open}) {
    _tokens = gateway.tokenRefresh
        .listen((token) => _save(token, _generation), onError: (Object _) {});
    _opens = gateway.opened.listen(_opened, onError: (Object _) {});
    unawaited(_initial());
  }
  final PushGateway gateway;
  final Future<void> Function(String) register;
  final Future<void> Function(String) open;
  late StreamSubscription<String> _tokens;
  late StreamSubscription<Map<String, dynamic>> _opens;
  String? _user;
  Map<String, dynamic>? _pending;
  int _generation = 0;
  bool _disposed = false, _opening = false, _permitted = false;
  Future<void> _writes = Future.value();

  Future<void> _initial() async {
    try {
      final message = await gateway.initialMessage();
      if (message != null && !_disposed) _opened(message);
    } catch (_) {/* Missing delivery never prevents app startup. */}
  }

  void _opened(Map<String, dynamic> data) {
    if (_disposed) return;
    if (_user == null) {
      _pending = data;
      return;
    }
    final id = pushNotificationId(data, _user);
    if (id == null || _opening) return;
    _opening = true;
    unawaited(open(id)
        .catchError((Object _) {})
        .whenComplete(() => _opening = false));
  }

  Future<void> setUser(String? user) async {
    final generation = ++_generation;
    _user = user;
    _permitted = false;
    if (user == null || _disposed) return;
    final pending = _pending;
    _pending = null;
    if (pending != null) _opened(pending);
    try {
      final granted = await gateway.requestPermission();
      if (_disposed || generation != _generation || !granted) return;
      _permitted = true;
      final token = await gateway.getToken();
      if (token != null) await _save(token, generation);
    } catch (_) {
      /* Optional push cannot block login or in-app notifications. */
    }
  }

  Future<void> _save(String token, int generation) {
    _writes = _writes.then((_) async {
      if (!_disposed &&
          _permitted &&
          _user != null &&
          generation == _generation &&
          token.isNotEmpty) {
        try {
          await register(token);
        } catch (_) {/* Retry on token refresh/resume. */}
      }
    });
    return _writes;
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_generation;
    await _tokens.cancel();
    await _opens.cancel();
  }
}

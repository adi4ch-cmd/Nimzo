import 'dart:async';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'voice_service.dart';

/// Safe stage/code diagnostics: never includes credentials or raw provider payloads.
class VoiceConnectionFailure extends StateError {
  VoiceConnectionFailure(super.message);
}

/// Owns one Vivox room. A successful join request is not an audio connection.
class VivoxVoiceService implements VoiceService {
  static const MethodChannel _channel = MethodChannel('nimzo/vivox');
  final Future<Map<String, dynamic>> Function(String) _tokenIssuer;
  final Duration connectionTimeout;
  final _speaking = StreamController<Set<String>>.broadcast();
  final _connectedEvents = StreamController<bool>.broadcast();
  @override
  Stream<bool> get connected => _connectedEvents.stream;

  final Set<String> _speakingUsers = <String>{};
  bool _initialized = false, _connected = false, _disposed = false;
  Completer<void>? _connection;
  String? _roomId;
  bool _canTransmit = false;
  VoiceConnectionFailure? _nativeFailure;
  int _sessionGeneration = 0;
  Future<void> _operations = Future.value();

  VivoxVoiceService({
    Future<Map<String, dynamic>> Function(String)? tokenIssuer,
    this.connectionTimeout = const Duration(seconds: 25),
  }) : _tokenIssuer = tokenIssuer ?? _issueVoiceToken {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  @override
  Stream<Set<String>> get speaking => _speaking.stream;

  Future<dynamic> _handleNativeEvent(MethodCall call) async {
    if (_disposed) return null;
    final args = call.arguments is Map ? call.arguments as Map : const {};
    final detail = '${args['detail'] ?? ''}';
    final status = (args['status'] as num?)?.toInt() ?? 0;
    if (call.method == 'audioConnected' && status == 0 && _connection != null) {
      _connected = true;
      _connectedEvents.add(true);
      if (_connection?.isCompleted == false) _connection!.complete();
    } else if (call.method == 'error' ||
        (status != 0 &&
            (call.method == 'audioState' || call.method == 'loginState'))) {
      _connected = false;
      _connectedEvents.add(false);
      _speakingUsers.clear();
      _speaking.add(const <String>{});
      if (_connection?.isCompleted == false) {
        _connection!.completeError(
          _nativeFailure = _nativeError(status, detail),
        );
      } else {
        _nativeFailure = _nativeError(status, detail);
      }
    } else if (call.method == 'speaking' || call.method == 'stoppedSpeaking') {
      // Vivox account URI: sip:.issuer.<Supabase UUID>@domain.
      final id = RegExp(
        r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(?=\.?@|$)',
      ).firstMatch(detail)?.group(1);
      if (id != null) {
        call.method == 'speaking'
            ? _speakingUsers.add(id)
            : _speakingUsers.remove(id);
        _speaking.add(Set.unmodifiable(_speakingUsers));
      }
    } else if (call.method == 'left' || call.method == 'audioDisconnected') {
      _connected = false;
      _connectedEvents.add(false);
      _speakingUsers.clear();
      _speaking.add(const <String>{});
      if (_connection?.isCompleted == false) {
        _connection!.completeError(
          VoiceConnectionFailure(
            'Voice audio disconnected during connection. Retry voice.',
          ),
        );
      }
    }
    return null;
  }

  VoiceConnectionFailure _nativeError(int code, String detail) {
    const stages = {
      'connector',
      'initialize',
      'login',
      'initial-mute',
      'channel-join',
      'microphone',
      'speaker',
      'leave',
    };
    final stage = stages.contains(detail) ? detail : 'native';
    return VoiceConnectionFailure(
      'Voice $stage failed (code $code). Retry voice.',
    );
  }

  Future<T?> _invokeNative<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      // Java exception messages can contain credentials or provider payloads.
      const codes = {'VIVOX_NATIVE', 'PERMISSION_PENDING'};
      const types = {
        'UnsatisfiedLinkError',
        'NoClassDefFoundError',
        'NoSuchMethodError',
        'ExceptionInInitializerError',
        'SecurityException',
        'IllegalArgumentException',
        'IllegalStateException',
        'NullPointerException',
        'RuntimeException',
      };
      final details = error.details;
      final type = details is Map ? details['type'] : null;
      final code = codes.contains(error.code) ? error.code : 'PLATFORM';
      final diagnostic = types.contains(type) ? '$code, $type' : code;
      throw VoiceConnectionFailure(
        'Voice $method failed ($diagnostic). Retry voice.',
      );
    }
  }

  static Future<Map<String, dynamic>> _issueVoiceToken(String roomId) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null)
      throw StateError('You must be signed in before joining voice.');
    final response = await client.functions.invoke(
      'voice-token',
      body: {'room': roomId},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.data is! Map)
      throw StateError('Invalid voice-token response.');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operations.then((_) => action());
    _operations = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> join(String roomId, String token) =>
      _serialize(() => _join(roomId));

  Future<void> _join(String roomId, {Map<String, dynamic>? credentials}) async {
    if (_disposed) throw StateError('Voice service is closed.');
    final generation = _sessionGeneration;
    if (_initialized) await _leave();
    // Vivox requires capture access before joining even when initially muted.
    if (await _invokeNative<bool>('requestMicPermission') != true) {
      throw VoiceConnectionFailure(
        'Microphone permission is required for room audio.',
      );
    }
    final Map<String, dynamic> data;
    try {
      data = credentials ?? await _tokenIssuer(roomId);
    } on FunctionException catch (error) {
      final detail = error.details;
      final message = detail is Map ? detail['error'] : null;
      throw VoiceConnectionFailure(
        message == 'Vivox voice service is not configured'
            ? 'Voice server is not configured (HTTP 503). Contact support.'
            : 'Voice token request failed (HTTP ${error.status}). Retry voice.',
      );
    }
    if (generation != _sessionGeneration || _disposed)
      throw StateError('Voice join cancelled.');
    for (final key in [
      'loginToken',
      'channelToken',
      'server',
      'channelUri',
      'accountUri',
    ]) {
      if (data[key] is! String || (data[key] as String).isEmpty) {
        throw StateError('Vivox voice-token response is incomplete.');
      }
    }
    // SDK account name must match the server-signed login token's SIP identity.
    final identity = RegExp(
      r'^sip:(\.[A-Za-z0-9=+_.!~()\-]+\.)@[A-Za-z0-9.-]+$',
    ).firstMatch(data['accountUri'] as String);
    final accountName = identity?.group(1);
    if (accountName == null || accountName.length > 127) {
      throw VoiceConnectionFailure(
        'Voice account configuration is invalid. Contact support.',
      );
    }
    if (!_initialized) {
      _nativeFailure = null;
      final bool? ok;
      try {
        ok = await _invokeNative<bool>('initialize', {
          'server': data['server'],
        });
      } catch (_) {
        try {
          await _invokeNative<int>('shutdown');
        } catch (_) {
          /* Preserve the initialization diagnostic. */
        }
        rethrow;
      }
      if (ok != true) {
        await _invokeNative<int>('shutdown');
        throw _nativeFailure ??
            VoiceConnectionFailure('Voice initialization failed. Retry voice.');
      }
      _initialized = true;
    }
    _connected = false;
    if (generation != _sessionGeneration || _disposed)
      throw StateError('Voice join cancelled.');
    final pending = Completer<void>();
    _connection = pending;
    // Observe errors before native callbacks; media timeout starts AFTER native
    // login/mute/join acceptance, whose own bounded stages can take 45 seconds.
    final connected = pending.future;
    // Consume errors immediately while the native join response is pending.
    unawaited(connected.catchError((Object _) {}));
    try {
      final result = await _invokeNative<int>('join', {
        'loginToken': data['loginToken'],
        'channelToken': data['channelToken'],
        'channelUri': data['channelUri'],
        'accountName': accountName,
      });
      if (result != 0)
        throw _nativeFailure ??
            VoiceConnectionFailure(
              'Voice native join failed (code $result). Retry voice.',
            );
      await connected.timeout(
        connectionTimeout,
        onTimeout: () => throw VoiceConnectionFailure(
          'Voice audio connection timed out. Retry voice.',
        ),
      );
      final muted = await _invokeNative<int>('setMic', {'enabled': false});
      if (muted != 0)
        throw StateError('Vivox initial mute failed (code $muted).');
      if (!_connected || generation != _sessionGeneration || _disposed) {
        throw VoiceConnectionFailure(
          'Voice audio disconnected during connection. Retry voice.',
        );
      }
      _roomId = roomId;
      _canTransmit = data['canTransmit'] == true;
    } catch (_) {
      try {
        await _leave();
      } catch (_) {
        /* Preserve the original connection failure. */
      }
      rethrow;
    } finally {
      _connection = null;
    }
  }

  Future<void> _leave() async {
    _connected = false;
    if (!_disposed) _connectedEvents.add(false);
    try {
      if (_initialized) {
        try {
          await _invokeNative<int>('leave');
        } finally {
          // Attempt teardown even when leaving fails. A platform exception must
          // not retain handles or speaking state in the next room session.
          await _invokeNative<int>('shutdown');
        }
      }
    } finally {
      _initialized = false;
      _roomId = null;
      _canTransmit = false;
      _speakingUsers.clear();
      if (!_disposed) _speaking.add(const <String>{});
    }
  }

  @override
  Future<void> leave() {
    _sessionGeneration++;
    _connected = false;
    if (_connection?.isCompleted == false)
      _connection!.completeError(StateError('Voice join cancelled.'));
    return _serialize(_leave);
  }

  @override
  Future<void> setMicEnabled(bool enabled) => _serialize(() async {
    if (_disposed || !_connected)
      throw StateError('Voice audio is not connected.');
    if (enabled && await _invokeNative<bool>('requestMicPermission') != true) {
      throw StateError('Microphone permission is required to speak.');
    }
    if (!_connected || _disposed)
      throw StateError('Voice audio is not connected.');
    if (enabled) {
      final roomId = _roomId;
      if (roomId == null) throw StateError('Voice room is not joined.');
      final credentials = await _tokenIssuer(roomId);
      if (!_connected || _disposed)
        throw StateError('Voice audio is not connected.');
      if (credentials['canTransmit'] != true) {
        await _leave();
        throw StateError('Your seat is not authorized to transmit room audio.');
      }
      // A listener's join_muted token cannot be unmuted locally. Upgrade by
      // joining with a new server-authorized token after the seat was granted.
      if (!_canTransmit) await _join(roomId, credentials: credentials);
      if (!_connected || _disposed)
        throw StateError('Voice audio is not connected.');
    }
    final result = await _invokeNative<int>('setMic', {'enabled': enabled});
    if (result != 0)
      throw StateError('Vivox microphone request failed (code $result).');
  });

  @override
  Future<void> setSpeakerEnabled(bool enabled) => _serialize(() async {
    if (_disposed || !_connected)
      throw StateError('Voice audio is not connected.');
    final result = await _invokeNative<int>('setSpeaker', {'enabled': enabled});
    if (result != 0)
      throw StateError('Vivox speaker request failed (code $result).');
  });

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await leave();
    } finally {
      await _serialize(() async {
        _disposed = true;
        try {
          if (_initialized) await _invokeNative<int>('shutdown');
        } finally {
          _initialized = false;
          _channel.setMethodCallHandler(null);
          await _speaking.close();
          await _connectedEvents.close();
        }
      });
    }
  }
}

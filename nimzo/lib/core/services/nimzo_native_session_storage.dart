import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Android native fallback for Supabase Flutter v2's legacy preferences keys.
/// This is persistent and uses Flutter's existing preference file; it never
/// creates an ephemeral session store or silently logs users out.
class NimzoNativeSessionStorage extends LocalStorage {
  NimzoNativeSessionStorage({required this.persistSessionKey});

  static const MethodChannel channel = MethodChannel('nimzo/auth_storage');
  final String persistSessionKey;

  @override
  Future<void> initialize() async {
    final ready = await channel.invokeMethod<bool>('probe');
    if (ready != true) throw const PlatformException(code: 'NATIVE_STORAGE_UNAVAILABLE');
  }

  @override
  Future<bool> hasAccessToken() async =>
      (await channel.invokeMethod<bool>('contains', {'key': persistSessionKey})) == true;

  @override
  Future<String?> accessToken() =>
      channel.invokeMethod<String>('read', {'key': persistSessionKey});

  @override
  Future<void> persistSession(String persistSessionString) async {
    final stored = await channel.invokeMethod<bool>('write', {
      'key': persistSessionKey, 'value': persistSessionString,
    });
    if (stored != true) throw const PlatformException(code: 'SESSION_WRITE_FAILED');
  }

  @override
  Future<void> removePersistedSession() async {
    final removed = await channel.invokeMethod<bool>('remove', {
      'key': persistSessionKey,
    });
    if (removed != true) throw const PlatformException(code: 'SESSION_REMOVE_FAILED');
  }
}

/// Keeps existing PKCE OAuth verifiers in the same legacy storage namespace.
class NimzoNativePkceStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) =>
      NimzoNativeSessionStorage.channel.invokeMethod<String>('read', {'key': key});

  @override
  Future<void> setItem({required String key, required String value}) async {
    final ok = await NimzoNativeSessionStorage.channel.invokeMethod<bool>(
      'write', {'key': key, 'value': value},
    );
    if (ok != true) throw const PlatformException(code: 'PKCE_WRITE_FAILED');
  }

  @override
  Future<void> removeItem({required String key}) async {
    final ok = await NimzoNativeSessionStorage.channel.invokeMethod<bool>(
      'remove', {'key': key},
    );
    if (ok != true) throw const PlatformException(code: 'PKCE_REMOVE_FAILED');
  }
}

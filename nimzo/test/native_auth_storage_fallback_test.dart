import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/nimzo_native_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = NimzoNativeSessionStorage.channel;

  test('native session fallback keeps existing login state and PKCE keys', () async {
    final preferences = <String, String>{
      // Represents an existing SharedPreferencesLocalStorage v2 session.
      'sb-kvqvlpozqokwarovwmwv-auth-token': 'existing-session',
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'probe') return true;
      final key = call.arguments['key'] as String;
      switch (call.method) {
        case 'read': return preferences[key];
        case 'contains': return preferences.containsKey(key);
        case 'write':
          preferences[key] = call.arguments['value'] as String;
          return true;
        case 'remove':
          preferences.remove(key);
          return true;
      }
      throw PlatformException(code: 'unsupported_method');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final storage = NimzoNativeSessionStorage(
      persistSessionKey: 'sb-kvqvlpozqokwarovwmwv-auth-token',
    );
    await storage.initialize();
    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), 'existing-session');

    await storage.persistSession('refreshed-session');
    expect(await storage.accessToken(), 'refreshed-session');

    final pkce = NimzoNativePkceStorage();
    const verifierKey = 'supabase.auth.token-code-verifier';
    await pkce.setItem(key: verifierKey, value: 'pending-oauth-verifier');
    expect(await pkce.getItem(key: verifierKey), 'pending-oauth-verifier');
    await pkce.removeItem(key: verifierKey);
    expect(await pkce.getItem(key: verifierKey), isNull);

    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('native store refuses writes that fail, never pretends persistence', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'probe') return true;
      if (call.method == 'write') return false;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final storage = NimzoNativeSessionStorage(
      persistSessionKey: 'sb-kvqvlpozqokwarovwmwv-auth-token',
    );
    await storage.initialize();
    await expectLater(
      storage.persistSession('session'),
      throwsA(isA<PlatformException>()),
    );
  });
}

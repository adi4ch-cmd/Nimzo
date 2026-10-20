import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bootstrap renders Flutter before awaiting network or FCM', () {
    final source = File('lib/main.dart').readAsStringSync();
    final render = source.indexOf('runApp(const NimzoBootstrapApp());');
    expect(render, greaterThanOrEqualTo(0));
    expect(source.indexOf('Supabase.initialize('), greaterThan(render));
    expect(source.indexOf('await initializeFirebasePush()'), greaterThan(render));
    expect(source, contains('timeout(const Duration(seconds: 12))'));
    expect(source, contains('Future<Supabase>? _supabaseInitialization;'));
    expect(source, contains('SharedPreferences.getInstance()'));
    expect(source, contains("_startupStage = 'android-storage'"));
    expect(source, contains("_startupStage = 'supabase-auth'"));
    expect(source, contains('_supabaseInitialization = null;'));
    expect(source, contains('_safeStartupMessage(error)'));
    expect(source, contains('timeout(const Duration(seconds: 8))'));
    expect(source, contains('UncontrolledProviderScope('));
    expect(source, contains('child: const NimzoApp()'));
    expect(source, contains("child: const Text('Retry')"));
  });

  test('Push stays available after UI first frame', () {
    final fcm = File('lib/core/services/firebase_push_service.dart')
        .readAsStringSync();
    expect(fcm, contains('pushGatewayStateProvider'));
    expect(fcm, contains('ref.watch(pushGatewayStateProvider)'));
    expect(fcm, contains('pushLifecycleProvider'));
  });

  test('Offline profile fetch cannot block startup indefinitely', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains('timeout(const Duration(seconds: 6))'));
    expect(router, contains('profileReady = true;'));
    expect(router, contains('path: Routes.events'));
    expect(router, contains('path: Routes.games'));
    expect(router, contains('RoyalStoreScreen('));
  });
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/vip/phoenix_entitlement.dart';
import 'package:nimzo/features/vip/phoenix_widgets.dart';

Map<String, dynamic> membership({int seconds = 60, int level = 6}) => {
      'vip_level': level,
      'server_now': '2001-01-01T00:00:00Z',
      'vip_expires_at':
          DateTime.utc(2001).add(Duration(seconds: seconds)).toIso8601String(),
    };
void main() {
  testWidgets('server time activates target identity and expiry removes frame',
      (tester) async {
    final calls = <String>[];
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/phoenix_membership');
          calls.add((jsonDecode(request.body) as Map)['p_user'] as String);
          return http.Response(jsonEncode(membership(seconds: 1)), 200,
              request: request, headers: {'content-type': 'application/json'});
        }))))!;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('viewer')
        ],
        child: const MaterialApp(
            home: PhoenixDecoration(
                userId: 'target',
                avatar: true,
                child: CircleAvatar(child: Text('Target'))))));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.byType(PhoenixFrame), findsOneWidget);
    expect(calls, ['target']); // Viewer ID grants no access to the target.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PhoenixFrame), findsNothing);
    expect(find.text('Target'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(db.dispose);
  });

  testWidgets('failed refresh and backgrounding remove Phoenix cosmetics',
      (tester) async {
    var fail = false;
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async => http.Response(
            fail ? '{"message":"unavailable"}' : jsonEncode(membership()),
            fail ? 503 : 200,
            request: request,
            headers: {'content-type': 'application/json'})))))!;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('viewer')
        ],
        child: const MaterialApp(
            home: PhoenixDecoration(
                userId: 'target', avatar: true, child: Text('Target')))));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.byType(PhoenixFrame), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(PhoenixFrame), findsNothing);
    fail = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.byType(PhoenixFrame), findsNothing);
    expect(find.text('Target'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(db.dispose);
  });

  testWidgets('premium nameplate fits narrow layout and large text',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          phoenixEntitlementProvider.overrideWith((_, id) =>
              Stream.value(PhoenixEntitlement.fromJson(membership())))
        ],
        child: const MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    textScaler: TextScaler.linear(3), disableAnimations: true),
                child: Center(
                    child: SizedBox(
                        width: 140,
                        child: PhoenixNameplate(
                            userId: 'target',
                            name:
                                'Very long premium Phoenix member name')))))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('animated frame pauses when offscreen or reduced motion changes',
      (tester) async {
    Widget frame(bool enabled, bool reduced) => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
                enabled: enabled,
                child: const Center(
                    child:
                        PhoenixFrame(child: CircleAvatar(child: Text('N')))))));
    await tester.pumpWidget(frame(true, false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(frame(false, false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(frame(true, true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}

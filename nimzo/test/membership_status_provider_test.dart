import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/premium/willchill_premium_screen.dart';

void main() {
  test('effective status comes from authenticated RPC, not raw profile levels',
      () async {
    final requests = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(
            jsonEncode({
              'retired': true,
              'vip_level': 0,
              'svip_level': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final container = ProviderContainer(overrides: [
      sessionSupabaseProvider.overrideWithValue((client: client, userId: 'u')),
    ]);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
    final status = await container.read(membershipStatusProvider.future);
    expect(requests, ['/rest/v1/rpc/vip_status']);
    expect(status!.retired, isTrue);
    expect(status.canPurchase, isFalse);
  });

  test('signed-out state makes no database request', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient:
          MockClient((_) async => throw StateError('Unexpected request')),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final container = ProviderContainer(overrides: [
      sessionSupabaseProvider.overrideWithValue((client: client, userId: null)),
    ]);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
    expect(await container.read(membershipStatusProvider.future), isNull);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/tingle_tasks_screen.dart';

void main() {
  for (final completed in [true, false]) {
    test('daily room gift task uses verified caller status: $completed',
        () async {
      final requests = <http.Request>[];
      final db = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/gift_events')) {
            return http.Response('{"message":"permission denied"}', 403);
          }
          return http.Response(
            request.url.path.endsWith('/my_daily_room_gift_status')
                ? '$completed'
                : '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(db.dispose);
      final container = ProviderContainer(overrides: [
        supabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('me'),
        profileProvider('me')
            .overrideWith((_) async => const Profile(id: 'me', nimzoId: 1)),
      ]);
      addTearDown(container.dispose);
      final progress = await container.read(taskProgressProvider.future);
      expect(progress['gift'], completed);
      expect(requests.any((r) => r.url.path.endsWith('/gift_events')), isFalse);
    });
  }
}

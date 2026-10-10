import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/rooms/data/room_repository.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  test(
    'capability uses room only; separate kick/ban forward exact RPC args',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.url.path.endsWith('get_room_moderation') ? 'true' : 'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = RoomRepository(client);
      expect(await repository.canModerate('room'), isTrue);
      await repository.moderateMember('room', 'guest', ban: false);
      await repository.moderateMember('room', 'guest', ban: true);
      expect(requests[0].url.path, '/rest/v1/rpc/get_room_moderation');
      expect(jsonDecode(requests[0].body), {'p_room': 'room'});
      for (var i = 1; i < 3; i++) {
        expect(requests[i].url.path, '/rest/v1/rpc/moderate_room_member');
        expect(jsonDecode(requests[i].body), {
          'p_room': 'room',
          'p_user': 'guest',
          'p_ban': i == 2,
        });
      }
    },
  );

  test(
      'capability cache recomputes across account changes and signed out is false',
      () async {
    final account = StateProvider<String?>((_) => 'moderator');
    final repository = _Capabilities();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
        roomRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      roomModerationProvider('room'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    expect(await container.read(roomModerationProvider('room').future), isTrue);
    repository.allowed = false;
    container.read(account.notifier).state = 'member';
    expect(
      await container.read(roomModerationProvider('room').future),
      isFalse,
    );
    expect(repository.lookups, 2);
    container.read(account.notifier).state = null;
    expect(
      await container.read(roomModerationProvider('room').future),
      isFalse,
    );
    expect(repository.lookups, 2);
  });
}

class _Capabilities implements RoomRepository {
  bool allowed = true;
  int lookups = 0;
  @override
  Future<bool> canModerate(String roomId) async {
    lookups++;
    return allowed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

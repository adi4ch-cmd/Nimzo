import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/rooms/data/room_repository.dart';

void main() {
  test('invalid seat numbers never reach the server; seat 10 does', () async {
    final requested = <String>[];
    final paths = <String>[];
    final client = SupabaseClient('https://example.supabase.co', 'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requested.add(request.body);
      paths.add(request.url.path);
      return http.Response('null', 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repository = RoomRepository(client);
    for (final seat in [0, 11]) {
      await expectLater(repository.takeSeat('room', seat), throwsRangeError);
      await expectLater(
          repository.modMuteSeat('room', seat, true), throwsRangeError);
      await expectLater(
          repository.modLockSeat('room', seat, true), throwsRangeError);
      await expectLater(
          repository.modAssignSeat('room', seat, 'user'), throwsRangeError);
    }
    expect(requested, isEmpty);
    await repository.takeSeat('room', 10);
    expect(requested.single, contains('"p_seat":10'));
    await repository.modLockSeat('room', 10, true);
    await repository.modAssignSeat('room', 10, 'guest');
    expect(requested[1], contains('"p_locked":true'));
    expect(requested[2], contains('"p_user":"guest"'));
    expect(paths, [
      '/rest/v1/rpc/take_seat',
      '/rest/v1/rpc/mod_lock_seat',
      '/rest/v1/rpc/mod_assign_seat'
    ]);
  });
}

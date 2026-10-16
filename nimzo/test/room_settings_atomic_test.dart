import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/rooms/data/room_settings_repository.dart';

void main() {
  test('room settings and photo use one atomic authorized request', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await RoomSettingsRepository(client).save(
      'room',
      const RoomSettings(
        name: 'Updated room',
        theme: 'sage',
        isPrivate: true,
        avatarPath: 'room/new.jpg',
        mic: false,
      ),
      password: 'room-password',
    );
    expect(
      requests,
      hasLength(1),
      reason: 'Separate RPCs permit partial saves',
    );
    expect(requests.single.url.path, '/rest/v1/rpc/save_room_settings');
    expect(jsonDecode(requests.single.body), {
      'p_room': 'room',
      'p_name': 'Updated room',
      'p_theme': 'sage',
      'p_private': true,
      'p_password': 'room-password',
      'p_mic': false,
      'p_chat': true,
      'p_guest': true,
      'p_gift': true,
      'p_music': true,
      'p_game': true,
      'p_visitor': true,
      'p_avatar_path': 'room/new.jpg',
    });
  });
}

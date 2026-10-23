import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/rooms/polls/room_poll_sheet.dart';

void main() {
  testWidgets('confirmed creation rotates the key for a new poll after closure',
      (tester) async {
    final keys = <String>[];
    final polls = StateProvider<List<RoomPoll>>((_) => []);
    late ProviderContainer container;
    RoomPoll poll(bool active) => RoomPoll.fromJson({
          'id': 'poll',
          'creator_id': 'creator',
          'question': 'Which song?',
          'options': ['A', 'B'],
          'counts': [0, 0],
          'my_choice': null,
          'active': active,
          'can_close': true,
          'ends_at':
              DateTime.now().add(const Duration(minutes: 5)).toIso8601String()
        });
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/rpc/close_room_poll')) {
            container.read(polls.notifier).state = [poll(false)];
            return http.Response('null', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          expect(request.url.path, endsWith('/rpc/create_room_poll'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['p_expected_user'], 'creator');
          expect(body['p_options'], ['A', 'B']);
          keys.add(body['p_key'] as String);
          container.read(polls.notifier).state = [poll(true)];
          return http.Response('"poll"', 200,
              request: request, headers: {'content-type': 'application/json'});
        }))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('creator'),
          roomPollsProvider('room')
              .overrideWith((ref) => Stream.value(ref.watch(polls)))
        ],
        child: const MaterialApp(
            home: Scaffold(body: RoomPollSheet(roomId: 'room')))));
    container =
        ProviderScope.containerOf(tester.element(find.byType(RoomPollSheet)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Question'), 'Which song?');
    await tester.enterText(find.widgetWithText(TextField, 'Option 1'), 'A');
    await tester.enterText(find.widgetWithText(TextField, 'Option 2'), 'B');
    await tester.ensureVisible(find.text('Start vote'));
    await tester.tap(find.text('Start vote'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('End poll'));
    await tester.tap(find.text('End poll'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start vote'));
    await tester.tap(find.text('Start vote'));
    await tester.pumpAndSettle();
    expect(keys, hasLength(2));
    expect(keys[1], isNot(keys[0]));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'room poll casts the selected choice and displays real server counts',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('/rpc/cast_room_vote'));
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"choice":1,"duplicate":false}', 200,
              request: request, headers: {'content-type': 'application/json'});
        }))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('voter'),
          roomPollsProvider('room').overrideWith((_) => Stream.value([
                RoomPoll.fromJson({
                  'id': 'poll',
                  'creator_id': 'creator',
                  'question': 'Which song?',
                  'options': ['A', 'B'],
                  'counts': [2, 3],
                  'my_choice': null,
                  'active': true,
                  'can_close': false,
                  'ends_at': DateTime.now()
                      .add(const Duration(minutes: 5))
                      .toIso8601String()
                })
              ]))
        ],
        child: const MaterialApp(
            home: Scaffold(body: RoomPollSheet(roomId: 'room')))));
    await tester.pumpAndSettle();
    expect(find.text('2 votes'), findsOneWidget);
    expect(find.text('3 votes'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(requests.single,
        {'p_poll': 'poll', 'p_choice': 1, 'p_expected_user': 'voter'});
    expect(find.text('Vote recorded.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('roomless poll has no fake voting or create controls',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: RoomPollSheet()))));
    await tester.pumpAndSettle();
    expect(
        find.text('Join a room to create or vote in a poll.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}

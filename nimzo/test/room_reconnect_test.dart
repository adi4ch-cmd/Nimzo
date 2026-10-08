import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/rooms/data/room_repository.dart';
import 'package:nimzo/features/rooms/data/room_chat_repository.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/rooms/presentation/room_screen.dart';
import 'package:nimzo/features/voice/voice_service.dart';
import 'package:nimzo/features/voice/voice_controller.dart';
import 'package:nimzo/core/widgets/master_ui.dart';

final room = Room(
    id: 'room',
    roomNo: 123,
    name: 'Room',
    ownerId: 'owner',
    theme: 'nimzo_white',
    isPrivate: false,
    status: 'open',
    createdAt: DateTime(2026));

class ReconnectRepository extends RoomRepository {
  ReconnectRepository(super.db);
  int memberships = 0;
  @override
  Future<Room> get(String id) async => room;
  @override
  Future<void> join(String id, {String? password}) async {
    memberships++;
  }

  @override
  Future<void> leave(String id) async {}
}

class ReconnectVoice implements VoiceService {
  final events = StreamController<bool>.broadcast();
  int joins = 0;
  int leaves = 0;
  final micPending = Completer<void>();
  final micRequests = <bool>[];
  @override
  Stream<bool> get connected => events.stream;
  @override
  Stream<Set<String>> get speaking => const Stream.empty();
  @override
  Future<void> join(String id, String token) async {
    joins++;
    events.add(true);
  }

  @override
  Future<void> leave() async {
    leaves++;
    events.add(false);
  }

  @override
  Future<void> dispose() => events.close();
  @override
  Future<void> setMicEnabled(bool enabled) {
    if (!enabled) return Future.error(StateError('Mic disable failed'));
    micRequests.add(enabled);
    return micPending.future;
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}
}

class PendingRoomChat extends RoomChatRepository {
  PendingRoomChat(super.db);
  final pending = Completer<void>();
  int sends = 0;
  @override
  Future<void> send(String roomId, String body) {
    sends++;
    return pending.future;
  }
}

void main() {
  testWidgets('room exposes voice reconnect without joining membership twice',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final repo = ReconnectRepository(db);
    final voice = ReconnectVoice();
    final chat = PendingRoomChat(db);
    final seats = StreamController<List<MicSeat>>.broadcast();
    addTearDown(seats.close);
    addTearDown(voice.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('viewer'),
      roomRepositoryProvider.overrideWithValue(repo),
      roomChatRepositoryProvider.overrideWithValue(chat),
      roomProvider('room').overrideWith((_) async => room),
      seatsProvider('room').overrideWith((_) => seats.stream),
      roomSeatProfilesProvider('room').overrideWith((_) async => {}),
      onlineCountProvider('room').overrideWith((_) => Stream.value(1)),
      roomChatProvider('room').overrideWith((_) => Stream.value([])),
      voiceServiceProvider.overrideWithValue(voice),
    ], child: const MaterialApp(home: RoomScreen(roomId: 'room'))));
    await tester.pumpAndSettle();
    expect(find.byType(DashedCircle), findsNWidgets(10));
    final seatCenters = find
        .byType(DashedCircle)
        .evaluate()
        .map((e) => tester.getCenter(find.byWidget(e.widget)))
        .toList();
    expect(seatCenters.take(5).map((p) => p.dy).toSet().length, 1);
    expect(seatCenters.skip(5).map((p) => p.dy).toSet().length, 1);
    expect(seatCenters[5].dy, greaterThan(seatCenters[0].dy));
    expect(seatCenters.take(5).map((p) => p.dx).toList(),
        seatCenters.skip(5).map((p) => p.dx).toList());
    await tester.tap(find.byTooltip('Microphone'));
    await tester.pump();
    await tester.tap(find.byTooltip('Microphone'));
    await tester.pump();
    expect(voice.micRequests, [true]);
    voice.micPending.complete();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First message');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(chat.sends, 1);
    await tester.enterText(find.byType(TextField), 'Next room draft');
    chat.pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Next room draft');
    seats.add(List.generate(10, (i) => MicSeat(seatNo: i + 1)));
    await tester.pumpAndSettle();
    expect(voice.leaves, 1);
    voice.events.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Voice disconnected. Retry voice.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(voice.joins, 2);
    expect(repo.memberships, 1);
    expect(find.text('Voice disconnected. Retry voice.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

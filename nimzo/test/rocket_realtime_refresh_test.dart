import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';

// Only the network boundary is replaced: exercise the repository's real
// registration, filtering, refresh and cleanup behavior.
class TestChannel implements RealtimeChannel {
  final callbacks = <String, void Function(PostgresChangePayload)>{};
  void Function(RealtimeSubscribeStatus, Object?)? statusCallback;

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload) callback,
  }) {
    callbacks[table!] = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) {
    statusCallback = callback;
    return this;
  }

  void insert(String table, Map<String, dynamic> row) {
    callbacks[table]?.call(PostgresChangePayload(
      schema: 'public',
      table: table,
      commitTimestamp: DateTime.now(),
      eventType: PostgresChangeEvent.insert,
      newRecord: row,
      oldRecord: const {},
      errors: null,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestClient extends SupabaseClient {
  TestClient()
      : super('https://example.supabase.co', 'key',
            authOptions: const AuthClientOptions(autoRefreshToken: false));
  final events = TestChannel();
  bool removed = false;
  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) =>
      events;
  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removed = true;
    return 'ok';
  }
}

void main() {
  test('readable verified gifts refresh Rocket below a milestone', () async {
    final db = TestClient();
    addTearDown(db.dispose);
    final updates = <DiamondUpdate>[];
    final subscription =
        RoomDiamondRepository(db).changes('room').listen(updates.add);
    addTearDown(subscription.cancel);

    db.events
        .insert('gift_animation_events', {'room_id': 'room', 'scope': 'room'});
    await Future<void>.delayed(Duration.zero);
    expect(updates, hasLength(1));
    expect(updates.single.blast, isNull);
    expect(db.events.callbacks, isNot(contains('gift_events')),
        reason: 'Payment receipts are private and cannot emit client updates');

    db.events.insert('gift_animation_events', {'room_id': 'another-room'});
    await Future<void>.delayed(Duration.zero);
    expect(updates, hasLength(1));
    db.events.statusCallback!(RealtimeSubscribeStatus.subscribed, null);
    await Future<void>.delayed(Duration.zero);
    expect(updates, hasLength(2),
        reason: 'Reconnect must reload server totals');
    await subscription.cancel();
    expect(db.removed, isTrue);
  });
}

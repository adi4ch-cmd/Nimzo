import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only invalidates reads; database RLS remains authoritative for event access.
Stream<int> accountTableActivity(
    SupabaseClient db, String table, List<String> userColumns) {
  final user = db.auth.currentUser?.id;
  if (user == null) return const Stream.empty();
  late StreamController<int> events;
  late RealtimeChannel channel;
  Timer? debounce;
  var counter = 0, subscribed = false, active = false;
  void changed() {
    if (!active) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 200), () {
      if (active) events.add(++counter);
    });
  }

  events = StreamController<int>(onListen: () {
    active = true;
    channel =
        db.channel('account-$table-${DateTime.now().microsecondsSinceEpoch}');
    for (final column in userColumns) {
      channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: column, value: user),
          callback: (_) => changed());
    }
    channel.subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (subscribed) changed();
        subscribed = true;
      }
    });
  }, onCancel: () async {
    active = false;
    debounce?.cancel();
    await db.removeChannel(channel);
  });
  return events.stream;
}

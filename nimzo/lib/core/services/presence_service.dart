import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';

class PresenceRepository {
  PresenceRepository(this.db);
  final SupabaseClient db;
  Future<void> heartbeat(bool online) async {
    if (await db.rpc('set_presence', params: {'p_online': online}) != true) {
      throw StateError('Presence was not confirmed');
    }
  }

  Future<Map<String, bool>> statuses(List<String> users) async {
    final uniqueUsers = users.toSet().toList();
    final result = <String, bool>{};
    for (var offset = 0; offset < uniqueUsers.length; offset += 100) {
      final end = (offset + 100).clamp(0, uniqueUsers.length);
      final rows = await db.rpc('presence_status', params: {
        'p_users': uniqueUsers.sublist(offset, end),
      });
      for (final row in rows as List) {
        if (row['is_online'] is bool) {
          result[row['user_id'] as String] = row['is_online'] as bool;
        }
      }
    }
    return result;
  }
}

/// Serializes lifecycle changes: a slow foreground heartbeat cannot overtake
/// the later background update. Missing networks never imply online status.
class PresenceHeartbeat with WidgetsBindingObserver {
  PresenceHeartbeat(this.write) {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    active = state == null || state == AppLifecycleState.resumed;
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (active) unawaited(_flush());
    });
    unawaited(_flush());
  }
  final Future<void> Function(bool) write;
  late Timer timer;
  bool active = false, disposed = false, sending = false;
  Future<void> _flush() async {
    if (disposed || sending) return;
    sending = true;
    bool sent;
    do {
      sent = active;
      try {
        await write(sent);
      } catch (_) {/* Server TTL expires unconfirmed sessions. */}
    } while (!disposed && sent != active);
    sending = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (next == active || disposed) return;
    active = next;
    unawaited(_flush());
  }

  void dispose() {
    disposed = true;
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Do not issue a request with a replacement account's token on logout.
    // Crashed/logged-out sessions expire after the server's 90-second TTL.
  }
}

final presenceRepositoryProvider = Provider(
    (ref) => PresenceRepository(ref.watch(sessionSupabaseProvider).client));
final presenceLifecycleProvider =
    Provider.autoDispose<PresenceHeartbeat?>((ref) {
  final user = ref.watch(currentUserIdProvider);
  if (user == null) return null;
  final client = ref.watch(supabaseProvider);
  final repository = ref.watch(presenceRepositoryProvider);
  final heartbeat = PresenceHeartbeat((online) async {
    if (client.auth.currentUser?.id == user) await repository.heartbeat(online);
  });
  ref.onCancel(heartbeat.dispose);
  ref.onResume(ref.invalidateSelf);
  ref.onDispose(heartbeat.dispose);
  return heartbeat;
});

/// Sorted comma-separated IDs let Inbox rows share one bounded batch request.
final onlineStatusesProvider = FutureProvider.autoDispose
    .family<Map<String, bool>, String>((ref, key) async {
  if (key.isEmpty) return {};
  Timer? refresh;
  void schedule() {
    refresh?.cancel();
    refresh = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  }

  schedule();
  ref.onCancel(() => refresh?.cancel());
  ref.onResume(schedule);
  ref.onDispose(() => refresh?.cancel());
  return ref
      .watch(presenceRepositoryProvider)
      .statuses(key.split(',').toSet().toList());
});

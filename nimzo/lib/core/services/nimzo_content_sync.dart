import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../providers/supabase_provider.dart';

/// Read-only server revisions. Realtime subscription requires the migration
/// enabling nimzo_content_revisions in the supabase_realtime publication.
/// No data is written from the app and no payment is authorised here.
final nimzoContentRevisionsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }
  // Recover from missed websocket changes or long offline intervals without
  // depending on a permanent background service or rebuilding the app.
  final poll = Timer.periodic(const Duration(minutes: 3), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(poll.cancel);
  return session.client
      .from('nimzo_content_revisions')
      .stream(primaryKey: ['channel'])
      .order('channel');
});

/// Only active server-approved JSON settings are exposed to signed-in clients.
/// This is presentation/config data, NEVER trusted for coins or entitlements.
final nimzoRemoteSettingsProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return {};
  final rows = await session.client
      .from('nimzo_remote_settings')
      .select('key,payload')
      .eq('active', true);
  return {
    for (final row in rows)
      if (row['key'] is String && row['payload'] is Map)
        row['key'] as String:
            Map<String, dynamic>.from(row['payload'] as Map),
  };
});

/// Returns changed channels, including all channels when first subscribed.
/// Ignore duplicate/out-of-order emissions. A new revision invalidates only
/// its matching repository cache, not session, wallet or purchase state.
Set<String> changedContentChannels(
  List<Map<String, dynamic>>? previous,
  List<Map<String, dynamic>> current,
) {
  final oldValues = <String, int>{
    for (final row in previous ?? const <Map<String, dynamic>>[])
      if (row['channel'] is String && row['revision'] is num)
        row['channel'] as String: (row['revision'] as num).toInt(),
  };
  final changed = <String>{};
  for (final row in current) {
    final channel = row['channel'];
    final revision = row['revision'];
    if (channel is! String || revision is! num) continue;
    final before = oldValues[channel];
    if (before == null || revision.toInt() > before) changed.add(channel);
  }
  return changed;
}

/// Ensure returning from sleep/offline triggers an immediate version check
/// instead of waiting for the periodic network recovery interval.
final nimzoContentResumeProvider = Provider<void>((ref) {
  final observer = _NimzoContentResumeObserver(ref);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _NimzoContentResumeObserver extends WidgetsBindingObserver {
  _NimzoContentResumeObserver(this.ref);
  final Ref ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(nimzoContentRevisionsProvider);
      ref.invalidate(nimzoRemoteSettingsProvider);
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'phoenix_entitlement.dart';
import 'royal_lion_entry.dart';

bool phoenixEntryIsFresh({
  required DateTime? serverNow,
  required DateTime? createdAt,
  required Duration requestTime,
}) {
  if (serverNow == null || createdAt == null) return false;
  final age = serverNow.difference(createdAt) + requestTime;
  return age >= Duration.zero && age <= const Duration(seconds: 10);
}

final phoenixEntriesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
  return ref
      .watch(sessionSupabaseProvider)
      .client
      .from('phoenix_room_entries')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(50);
});

/// Events are written by the server only for genuine, entitled room joins.
/// One effect at a time, bounded backlog, never replay a reconnect snapshot.
class PhoenixRoomEntry extends ConsumerStatefulWidget {
  final String roomId;
  const PhoenixRoomEntry({super.key, required this.roomId});
  @override
  ConsumerState<PhoenixRoomEntry> createState() => _PhoenixRoomEntryState();
}

class _PhoenixRoomEntryState extends ConsumerState<PhoenixRoomEntry>
    with WidgetsBindingObserver {
  final seen = <String>{};
  final queue = <Map<String, dynamic>>[];
  bool baseline = false, checking = false, foreground = true;
  int generation = 0;
  Map<String, dynamic>? current;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    generation++;
    if (!foreground) {
      timer?.cancel();
      queue.clear();
      if (mounted) setState(() => current = null);
    }
  }

  Future<void> next() async {
    if (checking || current != null || queue.isEmpty || !foreground) return;
    checking = true;
    final requestGeneration = generation;
    final event = queue.removeAt(0);
    try {
      // Recheck entitlement and event age against the server, including queue delay.
      final elapsed = Stopwatch()..start();
      final raw = await ref
          .read(sessionSupabaseProvider)
          .client
          .rpc('phoenix_membership', params: {'p_user': event['user_id']});
      if (!mounted ||
          !foreground ||
          requestGeneration != generation ||
          raw is! Map) return;
      final json = Map<String, dynamic>.from(raw);
      final serverNow = DateTime.tryParse(json['server_now']?.toString() ?? '');
      final created = DateTime.tryParse(event['created_at']?.toString() ?? '');
      final entitlement = PhoenixEntitlement.fromJson(
        json,
        requestTime: elapsed.elapsed,
      );
      final svip = (json['svip_level'] as num?)?.toInt() ?? 0;
      final svipExpiry = DateTime.tryParse(
        json['svip_expires_at']?.toString() ?? '',
      );
      final svipRemaining = serverNow == null || svipExpiry == null
          ? Duration.zero : svipExpiry.difference(serverNow) - elapsed.elapsed;
      final svipActive = svip >= 1 && svip <= 10 &&
          svipRemaining > Duration.zero;
      if ((!entitlement.isPhoenix && !svipActive) ||
          !phoenixEntryIsFresh(
            serverNow: serverNow,
            createdAt: created,
            requestTime: elapsed.elapsed,
          )) return;
      setState(() => current = {
        ...event,
        '_vip_level': entitlement.isPhoenix ? entitlement.level : 0,
        '_svip_level': svipActive ? svip : 0,
        '_royal_lion': entitlement.isRoyalLion,
      });
      final lease = entitlement.isPhoenix
          ? entitlement.leaseRemaining : svipRemaining;
      final duration = lease < const Duration(milliseconds: 5500)
          ? lease : const Duration(milliseconds: 5500);
      timer = Timer(duration, () {
        if (!mounted) return;
        setState(() => current = null);
        unawaited(next());
      });
    } catch (_) {
      /* A missing or unavailable server event never grants decoration. */
    } finally {
      checking = false;
      if (current == null && mounted) unawaited(next());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(phoenixEntriesProvider(widget.roomId), (_, nextValue) {
      final events = nextValue.asData?.value;
      if (events == null) return;
      final me = ref.read(currentUserIdProvider);
      for (final event in events.reversed) {
        final id = event['id']?.toString();
        if (id == null || !seen.add(id)) continue;
        if (foreground &&
            queue.length < 5 &&
            (baseline || event['user_id'] == me)) queue.add(event);
      }
      baseline = true;
      // Server stream keeps only the latest 50, so prune only IDs no longer in it.
      if (seen.length > 200)
        seen.retainAll(events.map((e) => e['id'].toString()));
      unawaited(next());
    });
    if (current == null) return const SizedBox.shrink();
    if (current!['_royal_lion'] == true) {
      return RoyalLionEntry(
        key: ValueKey(current!['id']),
        name: current!['display_name']?.toString() ?? 'NIMZO member',
        onFinished: () {
          timer?.cancel();
          if (!mounted) return;
          setState(() => current = null);
          unawaited(next());
        },
      );
    }
    final vip = (current!['_vip_level'] as int?) ?? 0;
    final svip = (current!['_svip_level'] as int?) ?? 0;
    final label = svip > 0 ? 'SVIP $svip' : 'VIP $vip';
    return Center(
      child: Container(
        key: const ValueKey('verified-premium-room-entry'),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xf0172926),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: svip > 0
              ? const Color(0xffd7ad64)
              : const Color(0xff67c7a3)),
          boxShadow: const [
            BoxShadow(color: Color(0x2e000000), blurRadius: 12),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.workspace_premium, size: 26,
            color: svip > 0 ? const Color(0xffffd488)
              : const Color(0xff8cebc6)),
          const SizedBox(width: 10),
          Flexible(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$label · VERIFIED ENTRY',
                style: const TextStyle(color: Color(0xffffe8a5),
                  fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(height: 3),
              Text(current!['display_name']?.toString() ?? 'NIMZO member',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          )),
        ]),
      ),
    );
  }
}

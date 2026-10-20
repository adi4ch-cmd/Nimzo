import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../rooms/presentation/room_controller.dart';
import 'premium_cosmetics.dart';
import 'store_visual_equipment.dart';
import 'cosmetic_media_view.dart';

/// Plays only newly joined members, never replays the historical member list.
class RoomCosmeticEntrance extends ConsumerStatefulWidget {
  const RoomCosmeticEntrance({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<RoomCosmeticEntrance> createState() =>
      _RoomCosmeticEntranceState();
}

class _RoomCosmeticEntranceState extends ConsumerState<RoomCosmeticEntrance> {
  Set<String>? previous;
  final queue = Queue<CosmeticMedia>();
  CosmeticMedia? active;
  Timer? watchdog;
  int generation = 0;
  int epoch = 0;
  late ProviderSubscription<AsyncValue<List<String>>> membersSubscription;
  Future<void> _enqueue(List<String> ids) async {
    final requestEpoch = epoch;
    for (final id in ids.take(20)) {
      try {
        final appearance = await ref.read(
          storeVisualEquipmentProvider(id).future,
        );
        if (!mounted || epoch != requestEpoch) return;
        if (MediaQuery.disableAnimationsOf(context)) continue;
        final media = appearance['Rides'];
        if (media != null && queue.length < 10) queue.add(media);
      } catch (_) {
        /* A failed appearance fetch must not block room entry. */
      }
    }
    if (mounted && epoch == requestEpoch && active == null) _next();
  }

  void _next() {
    watchdog?.cancel();
    if (!mounted) return;
    setState(() {
      active = queue.isEmpty ? null : queue.removeFirst();
      generation++;
    });
    if (active != null) watchdog = Timer(const Duration(seconds: 15), _next);
  }

  @override
  void dispose() {
    epoch++;
    membersSubscription.close();
    watchdog?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
    ref.listenManual(currentUserIdProvider, (old, next) {
      if (old != next) setState(_reset);
    });
  }

  void _reset() {
    epoch++;
    generation++;
    watchdog?.cancel();
    previous = null;
    active = null;
    queue.clear();
  }

  @override
  void didUpdateWidget(covariant RoomCosmeticEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      membersSubscription.close();
      _reset();
      _subscribe();
    }
  }

  void _subscribe() {
    membersSubscription =
        ref.listenManual(roomMemberIdsProvider(widget.roomId), (_, state) {
      final ids = state.valueOrNull;
      if (ids == null) return;
      final old = previous;
      previous = ids.toSet();
      final me = ref.read(currentUserIdProvider);
      final joined = old == null
          ? ids.where((id) => id == me).toList()
          : ids.where((id) => !old.contains(id)).toList();
      if (joined.isNotEmpty) unawaited(_enqueue(joined));
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final media = active;
    final playbackGeneration = generation;
    if (media == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          aspectRatio: 750 / 600,
          child: CosmeticMediaView(
            key: ValueKey('$generation-${media.id}'),
            media: media,
            onFinished: () {
              // Ignore completion from a player that has already timed out.
              if (generation == playbackGeneration) _next();
            },
          ),
        ),
      ),
    );
  }
}

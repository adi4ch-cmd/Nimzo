import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/nimzo_content_sync.dart';
import '../rocket/room_rocket_config.dart';

const diamondTargets = originalRocketThresholds;

class RoomDiamondStatus {
  const RoomDiamondStatus({
    required this.totalCoins,
    required this.completedStages,
    required this.progress,
    required this.cycleStart,
    required this.resetAt,
    required this.serverNow,
    this.config = RoomRocketConfig.original,
  });
  final int totalCoins, completedStages;
  final double progress;
  final DateTime cycleStart, resetAt, serverNow;
  final RoomRocketConfig config;
  List<int> get thresholds => config.thresholds;
  int get configVersion => config.version;
  int get activeStage => completedStages.clamp(0, thresholds.length - 1);
  factory RoomDiamondStatus.fromJson(Map<String, dynamic> row) {
    final targets = row['thresholds'];
    final dynamicConfig = row.containsKey('config_version');
    final config = dynamicConfig
        ? RoomRocketConfig.fromJson(row)
        : RoomRocketConfig.original;
    final total = row['total_coins'], completed = row['completed_stages'];
    final progress = row['progress'];
    final dates = [row['cycle_start'], row['reset_at'], row['server_now']];
    if (targets is! List ||
        (!dynamicConfig &&
            (targets.length != 6 ||
                List.generate(6, (i) => targets[i] == diamondTargets[i])
                    .contains(false))) ||
        dates.any(
          (date) => date is! String || DateTime.tryParse(date) == null,
        ) ||
        total is! int ||
        total < 0 ||
        completed is! int ||
        completed < 0 ||
        completed > config.thresholds.length ||
        row['active_stage'] !=
            completed.clamp(0, config.thresholds.length - 1) ||
        progress is! num ||
        !progress.isFinite ||
        progress < 0 ||
        progress > 1) {
      throw const FormatException('Invalid server Diamond Blast status');
    }
    return RoomDiamondStatus(
      config: config,
      totalCoins: total,
      completedStages: completed,
      progress: progress.toDouble(),
      cycleStart: DateTime.parse(row['cycle_start'] as String).toUtc(),
      resetAt: DateTime.parse(row['reset_at'] as String).toUtc(),
      serverNow: DateTime.parse(row['server_now'] as String).toUtc(),
    );
  }
}

class DiamondBlastEvent {
  const DiamondBlastEvent({
    required this.id,
    required this.roomId,
    required this.stage,
    required this.cycleStart,
    this.createdAt,
    this.configVersion = 1,
    int? targetCoins,
    int? artworkStage,
  })  : _targetCoins = targetCoins,
        _artworkStage = artworkStage;
  final DateTime? createdAt;
  final String id, roomId;
  final int stage, configVersion;
  final int? _targetCoins, _artworkStage;
  int get targetCoins => _targetCoins ?? diamondTargets[stage];
  int get artworkStage => _artworkStage ?? stage + 1;
  final DateTime cycleStart;
  factory DiamondBlastEvent.fromJson(Map<String, dynamic> row) {
    final stage = row['stage'];
    final cycle = row['cycle_start'];
    final version = row['config_version'];
    final target = row['target_coins'];
    final artwork = row['artwork_stage'];
    final dynamicEvent = row.containsKey('config_version');
    if (cycle is! String ||
        DateTime.tryParse(cycle) == null ||
        row['id'] is! String ||
        row['room_id'] is! String ||
        stage is! int ||
        stage < 0 ||
        stage > 5 ||
        (dynamicEvent
            ? version is! int ||
                version < 1 ||
                target is! int ||
                target < 1 ||
                target > 9007199254740991 ||
                artwork is! int ||
                artwork < 1 ||
                artwork > 6
            : target != diamondTargets[stage])) {
      throw const FormatException('Invalid server Diamond Blast event');
    }
    return DiamondBlastEvent(
      configVersion: dynamicEvent ? version as int : 1,
      targetCoins: target as int,
      artworkStage: dynamicEvent ? artwork as int : stage + 1,
      id: row['id'] as String,
      roomId: row['room_id'] as String,
      stage: stage,
      cycleStart: DateTime.parse(row['cycle_start'] as String).toUtc(),
      createdAt: row['created_at'] is String
          ? DateTime.tryParse(row['created_at'] as String)?.toUtc()
          : null,
    );
  }
}

class DiamondUpdate {
  const DiamondUpdate(this.sequence, [this.blast]);
  final int sequence;
  final DiamondBlastEvent? blast;
}

class RoomDiamondRepository {
  RoomDiamondRepository(this.db);
  final SupabaseClient db;
  Future<RoomDiamondStatus> status(String roomId) async {
    final row =
        await db.rpc('room_rocket_status_v3', params: {'p_room': roomId});
    return RoomDiamondStatus.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Read the event's immutable published version, never today's active config.
  Future<RoomRocketConfig> config(int version) async {
    final row = await db
        .from('room_rocket_configs')
        .select()
        .eq('version', version)
        .not('published_at', 'is', null)
        .single();
    final parsed = RoomRocketConfig.fromJson(Map<String, dynamic>.from(row));
    if (parsed.version != version)
      throw const FormatException('Rocket version mismatch');
    return parsed;
  }

  Future<RoomRocketConfig> eventConfig(DiamondBlastEvent event) async {
    final pinned = await config(event.configVersion);
    if (event.stage >= pinned.thresholds.length ||
        pinned.thresholds[event.stage] != event.targetCoins ||
        pinned.artworkStages[event.stage] != event.artworkStage) {
      throw const FormatException(
          'Milestone differs from pinned Rocket version');
    }
    return pinned;
  }

  /// Recover server-settled Rocket threshold events if Realtime drops them.
  /// RLS limits the result to members of the active room. This read never
  /// creates blast events, grants prizes or writes wallet data.
  Future<List<DiamondBlastEvent>> recentBlasts(
    String roomId, {
    required DateTime since,
  }) async {
    final rows = await db
        .from('room_diamond_blast_events')
        .select(
            'id,room_id,stage,target_coins,cycle_start,created_at,config_version,artwork_stage')
        .eq('room_id', roomId)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: true)
        .limit(24);
    final results = <DiamondBlastEvent>[];
    for (final row in rows) {
      try {
        results.add(DiamondBlastEvent.fromJson(Map<String, dynamic>.from(row)));
      } on FormatException {
        // Never render a malformed or unsupported milestone.
      }
    }
    return results;
  }

  /// Historical milestones only; never enqueue these as live animations.
  Future<List<DiamondBlastEvent>> history(String roomId) async {
    final rows = await db
        .from('room_diamond_blast_events')
        .select(
            'id,room_id,stage,target_coins,cycle_start,created_at,config_version,artwork_stage')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .order('stage', ascending: false)
        .limit(60);
    return rows
        .map(
          (row) => DiamondBlastEvent.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Stream<DiamondUpdate> changes(String roomId) {
    late StreamController<DiamondUpdate> stream;
    var sequence = 0;
    final channel = db.channel(
      'room-diamond-$roomId-${DateTime.now().microsecondsSinceEpoch}',
    );
    stream = StreamController<DiamondUpdate>(
      onListen: () {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'gift_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            if (!stream.isClosed && payload.newRecord['room_id'] == roomId) {
              // Every settled gift refreshes progress, including subthreshold gifts.
              // Only verified blast rows below enqueue an animation.
              stream.add(DiamondUpdate(++sequence));
            }
          },
        );
        channel
            .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_diamond_blast_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            if (stream.isClosed) return;
            try {
              final event = DiamondBlastEvent.fromJson(payload.newRecord);
              if (event.roomId == roomId)
                stream.add(DiamondUpdate(++sequence, event));
            } on FormatException {
              /* Never animate malformed or unsupported events. */
            }
          },
        )
            .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed &&
              !stream.isClosed) {
            // Refresh on reconnect, without replaying old blast animations.
            stream.add(DiamondUpdate(++sequence));
          }
        });
      },
      onCancel: () async {
        await db.removeChannel(channel);
      },
    );
    return stream.stream;
  }
}

final roomDiamondRepositoryProvider = Provider(
  (ref) {
    ref.watch(nimzoContentRevisionsProvider.select((state) {
      for (final row in state.valueOrNull ?? const <Map<String, dynamic>>[]) {
        if (row['channel'] == 'settings') return row['revision'];
      }
      return null;
    }));
    return RoomDiamondRepository(ref.watch(sessionSupabaseProvider).client);
  },
);
final roomDiamondEventsProvider =
    StreamProvider.autoDispose.family<DiamondUpdate, String>(
  (ref, roomId) => ref.watch(roomDiamondRepositoryProvider).changes(roomId),
);
final roomDiamondStatusProvider = FutureProvider.autoDispose
    .family<RoomDiamondStatus, String>((ref, roomId) async {
  ref.watch(roomDiamondEventsProvider(roomId));
  Timer? timer;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
  });
  final status = await ref.watch(roomDiamondRepositoryProvider).status(roomId);
  if (disposed) return status;
  final remaining = status.resetAt.difference(status.serverNow);
  timer = Timer(
    remaining.isNegative
        ? const Duration(seconds: 1)
        : remaining < const Duration(seconds: 15)
            ? remaining
            : const Duration(seconds: 15),
    ref.invalidateSelf,
  );
  return status;
});

final roomRocketHistoryProvider = FutureProvider.autoDispose
    .family<List<DiamondBlastEvent>, String>((ref, roomId) {
  ref.watch(roomDiamondStatusProvider(roomId));
  return ref.watch(roomDiamondRepositoryProvider).history(roomId);
});

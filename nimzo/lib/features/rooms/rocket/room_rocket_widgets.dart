// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../../../core/providers/supabase_provider.dart';
import '../diamond/room_diamond_repository.dart';
import 'room_rocket_leaderboard.dart';
import 'room_rocket_playback.dart';
import 'room_rocket_config.dart';

// Six existing server milestones and twelve original transparent VAP clips.
// Do not change targets or charge/grant anything from this screen.
const roomRocketTargets = diamondTargets;
const _rocketTones = [
  Color(0xff35cd9f),
  Color(0xff42c4f1),
  Color(0xff9b84f5),
  Color(0xffff986c),
  Color(0xffffc851),
  Color(0xffffdd82),
];
const _rocketInk = Color(0xff123d31);
const _rocketGreen = Color(0xff087f5b);
const _rocketMuted = Color(0xff687c72);
const _rocketGold = Color(0xffa87c2b);

class RoomRocketSheet extends ConsumerStatefulWidget {
  const RoomRocketSheet({super.key, this.roomId});
  final String? roomId;

  @override
  ConsumerState<RoomRocketSheet> createState() => _RoomRocketSheetState();
}

class _RoomRocketSheetState extends ConsumerState<RoomRocketSheet> {
  int? selectedStage;
  bool showHistory = false;

  Future<void> _previewRocket(int stage, RoomRocketConfig config) async {
    // Only compiled in debug builds. This is media QA, not a paid gift,
    // server milestone, prize or wallet transaction.
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RoomRocketPlayback(
              stage: stage,
              targetCoins: config.thresholds[stage],
              config: config,
              onFinished: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).maybePop();
                }
              },
            ),
            Positioned(
              top: 40,
              left: 16,
              right: 54,
              child: SafeArea(
                child: Text(
                  'ROCKET ${stage + 1} LOCAL PREVIEW · 0 COINS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 36,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Close Rocket test',
                  color: Colors.white,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.roomId;
    final status = id == null ? null : ref.watch(roomDiamondStatusProvider(id));
    final current = status?.valueOrNull;
    final config = current?.config ?? RoomRocketConfig.original;
    final targets = config.thresholds;
    final selection = (selectedStage ?? current?.activeStage ?? 0).clamp(
      0,
      targets.length - 1,
    );
    final color = _rocketTones[
        (config.artworkStages[selection] - 1) % _rocketTones.length];

    return Material(
      color: const Color(0xfff7faf7),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: _rocketGreen.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.title,
                style: const TextStyle(
                  color: _rocketInk,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _rocketMuted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Row(
                key: const ValueKey('six-rocket-selector'),
                children: [
                  for (var stage = 0; stage < targets.length; stage++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: stage == targets.length - 1 ? 0 : 5),
                        child: _RocketStageTile(
                          stage: stage,
                          artworkStage: config.artworkStages[stage],
                          label: config.stageLabels[stage],
                          selected: stage == selection,
                          completed: current != null &&
                              stage < current.completedStages,
                          onTap: () => setState(() => selectedStage = stage),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: .19),
                            color.withValues(alpha: .04),
                            color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/room_rocket/posters/rocket_stage_${config.artworkStages[selection]}.png',
                      key: const ValueKey('selected-rocket-artwork'),
                      width: 258,
                      height: 220,
                      fit: BoxFit.contain,
                      semanticLabel:
                          'Rocket level ${selection + 1} animation artwork',
                      errorBuilder: (_, __, ___) => const Text(
                        'Rocket preview unavailable',
                        style: TextStyle(color: _rocketMuted),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                config.stageLabels[selection].toUpperCase(),
                style: const TextStyle(
                  color: _rocketInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${compactNumber(targets[selection])} cumulative coins',
                style: const TextStyle(color: _rocketMuted, fontSize: 12),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _rocketGreen.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  current == null
                      ? 'Room status not available'
                      : selection < current.completedStages
                          ? 'Completed'
                          : selection == current.activeStage
                              ? 'Current milestone'
                              : 'Not reached',
                  style: const TextStyle(
                    color: _rocketGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (kDebugMode)
                TextButton.icon(
                  key: const ValueKey('rocket-local-vap-preview'),
                  style: TextButton.styleFrom(foregroundColor: _rocketGreen),
                  onPressed: () => _previewRocket(selection, config),
                  icon: const Icon(Icons.play_circle_outline, size: 17),
                  label: const Text(
                    'Test Rocket Animation (Free)',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              const SizedBox(height: 12),
              if (id == null)
                const Text(
                  'Join a room to view Rocket progress.',
                  style: TextStyle(color: _rocketMuted),
                )
              else
                AsyncContent(
                  value: status!,
                  onRetry: () => ref.invalidate(roomDiamondStatusProvider(id)),
                  builder: (state) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xffe2ece5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${compactNumber(state.totalCoins)} gifted in this room today',
                          style: const TextStyle(
                            color: _rocketInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          label: 'Current Rocket milestone progress',
                          value: '${(state.progress * 100).round()} percent',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: state.progress,
                              backgroundColor: const Color(0xffe8f0e9),
                              color: _rocketGreen,
                              minHeight: 7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          state.completedStages == state.thresholds.length
                              ? (state.thresholds.length == 6
                                  ? 'All six Rocket levels completed!'
                                  : 'All Rocket levels completed!')
                              : '${state.config.stageLabels[state.activeStage]} · ${compactNumber(state.thresholds[state.activeStage])} cumulative coins',
                          style: const TextStyle(
                            color: _rocketMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _ResetCountdown(
                          resetAt: state.resetAt,
                          serverNow: state.serverNow,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 19,
                    color: _rocketGold,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Gifting Top 1–3',
                      key: ValueKey('rocket-ranking-heading'),
                      style: TextStyle(
                        color: _rocketInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'THIS CYCLE',
                    style: TextStyle(
                      color: _rocketMuted,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (id == null)
                const Text(
                  'Join a room to view gifting rankings.',
                  style: TextStyle(color: _rocketMuted),
                )
              else
                AsyncContent(
                  value: ref.watch(roomRocketLeaderboardProvider(id)),
                  onRetry: () =>
                      ref.invalidate(roomRocketLeaderboardProvider(id)),
                  builder: (leaders) => leaders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No verified room gifts in this cycle yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _rocketMuted, fontSize: 12),
                          ),
                        )
                      : Column(
                          children: [
                            for (final leader in leaders)
                              _RocketPodiumItem(leader: leader),
                          ],
                        ),
                ),
              if (id != null) ...[
                TextButton.icon(
                  key: const ValueKey('rocket-history-toggle'),
                  style: TextButton.styleFrom(foregroundColor: _rocketGreen),
                  onPressed: () => setState(() => showHistory = !showHistory),
                  icon: Icon(
                    showHistory ? Icons.expand_less : Icons.history,
                    size: 18,
                  ),
                  label: const Text('Milestone history'),
                ),
                if (showHistory)
                  AsyncContent(
                    value: ref.watch(roomRocketHistoryProvider(id)),
                    onRetry: () =>
                        ref.invalidate(roomRocketHistoryProvider(id)),
                    builder: (events) => events.isEmpty
                        ? const Text(
                            'No verified milestones recorded yet.',
                            style: TextStyle(color: _rocketMuted, fontSize: 12),
                          )
                        : Column(
                            children: [
                              const Text(
                                'Latest 60 milestones · times in UTC',
                                style: TextStyle(
                                  color: _rocketMuted,
                                  fontSize: 11,
                                ),
                              ),
                              for (final event in events)
                                ListTile(
                                  key: ValueKey('rocket-history-${event.id}'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.rocket_launch_outlined,
                                    color: _rocketGold,
                                  ),
                                  title: Text(
                                    'Rocket ${event.stage + 1} · ${compactNumber(event.targetCoins)} coins',
                                    style: const TextStyle(
                                      color: _rocketInk,
                                      fontSize: 12,
                                    ),
                                  ),
                                  subtitle: Text(
                                    (event.createdAt ?? event.cycleStart)
                                        .toUtc()
                                        .toIso8601String()
                                        .replaceFirst('T', ' ')
                                        .split('.')
                                        .first,
                                    style: const TextStyle(
                                      color: _rocketMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Verified gifts only · no extra wallet rewards',
                textAlign: TextAlign.center,
                style: TextStyle(color: _rocketMuted, fontSize: 10),
              ),
              const SizedBox(height: 4),
              const Text(
                'Daily reset · 11:00 p.m. Saudi time',
                style: TextStyle(color: _rocketMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RocketStageTile extends StatelessWidget {
  const _RocketStageTile({
    required this.stage,
    required this.artworkStage,
    required this.label,
    required this.selected,
    required this.completed,
    required this.onTap,
  });
  final int stage, artworkStage;
  final String label;
  final bool selected, completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: '$label${completed ? ', completed' : ''}',
        child: InkWell(
          key: ValueKey('rocket-stage-$stage'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 64,
            decoration: BoxDecoration(
              color: selected ? _rocketGreen : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _rocketGreen : const Color(0xffdce8df),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/room_rocket/posters/rocket_stage_$artworkStage.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 34),
                ),
                // Six levels share one row, including at narrow widths and
                // larger system text sizes. The parent semantics retain the full
                // level/completion label when its compact visual scales down.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lv${stage + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white : _rocketInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (completed) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.check_circle,
                          size: 9,
                          color:
                              selected ? const Color(0xffffdf8a) : _rocketGreen,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _RocketPodiumItem extends ConsumerWidget {
  const _RocketPodiumItem({required this.leader});
  final RoomRocketLeader leader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accents = [
      const Color(0xffdba926),
      const Color(0xff8ba4bd),
      const Color(0xffb78163),
    ];
    final accent = accents[leader.rank - 1];
    final avatar = leader.avatarPath == null
        ? null
        : ref
            .read(supabaseProvider)
            .storage
            .from('avatars')
            .getPublicUrl(leader.avatarPath!);
    return Container(
      key: ValueKey('rocket-top-' + leader.rank.toString()),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: accent, size: 22),
          const SizedBox(width: 6),
          Text(
            leader.rank.toString(),
            style: TextStyle(color: accent, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 9),
          NimzoAvatar(name: leader.displayName, url: avatar, size: 37),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leader.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _rocketInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'ID:' + leader.nimzoId.toString(),
                  style: const TextStyle(color: _rocketMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            compactNumber(leader.giftedCoins),
            style: TextStyle(color: accent, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ResetCountdown extends StatefulWidget {
  const _ResetCountdown({required this.resetAt, required this.serverNow});
  final DateTime resetAt, serverNow;

  @override
  State<_ResetCountdown> createState() => _ResetCountdownState();
}

class _ResetCountdownState extends State<_ResetCountdown> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  void _restart() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsed = Duration(seconds: timer.tick));
    });
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _ResetCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverNow != widget.serverNow ||
        oldWidget.resetAt != widget.resetAt) _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.resetAt.difference(widget.serverNow) - _elapsed;
    final safe = left.isNegative ? Duration.zero : left;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    return Text(
      'Reset countdown: ' + hours.toString() + ':' + minutes,
      style: const TextStyle(
        color: Color(0xffa87c2b),
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }
}

/// Uses the existing server-settled milestone event stream. The legacy
/// PostgreSQL names remain for old-app compatibility and historical records.
/// Only new room clients render a Rocket effect, never a Diamond burst.
class RoomRocketHost extends ConsumerStatefulWidget {
  const RoomRocketHost({
    super.key,
    required this.roomId,
    required this.enabled,
    required this.child,
    this.playbackBuilder,
  });
  final String roomId;
  final bool enabled;
  final Widget child;
  final Widget Function(DiamondBlastEvent, VoidCallback)? playbackBuilder;

  @override
  ConsumerState<RoomRocketHost> createState() => _RoomRocketHostState();
}

class _RoomRocketHostState extends ConsumerState<RoomRocketHost>
    with WidgetsBindingObserver {
  bool _foreground = true;
  final _queue = <DiamondBlastEvent>[];
  final _seen = <String>{};
  DateTime? _cycle;
  Timer? _recoveryTimer;
  bool _recovering = false;
  int _recoveryGeneration = 0;
  late DateTime _joinedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _joinedAt = DateTime.now().toUtc();
    if (widget.enabled) _startRecovery();
  }

  void _startRecovery() {
    _recoveryTimer?.cancel();
    _recoveryGeneration++;
    _joinedAt = DateTime.now().toUtc();
    // Realtime normally delivers immediate milestone events. Also query the
    // authoritative event table: mobile connections can miss INSERT messages.
    _recoveryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_recover());
    });
    unawaited(_recover());
  }

  Future<void> _recover() async {
    if (!mounted || !widget.enabled || !_foreground || _recovering) return;
    _recovering = true;
    final generation = _recoveryGeneration;
    final targetRoom = widget.roomId;
    try {
      final events = await ref.read(roomDiamondRepositoryProvider).recentBlasts(
            targetRoom,
            since: _joinedAt.subtract(const Duration(seconds: 2)),
          );
      if (!mounted ||
          !widget.enabled ||
          generation != _recoveryGeneration ||
          targetRoom != widget.roomId) {
        return;
      }
      for (final event in events) {
        _enqueue(event);
      }
    } catch (_) {
      // A temporary offline/RLS failure never invents an animation; next
      // scheduled poll retries while the room is still joined.
    } finally {
      _recovering = false;
    }
  }

  void _enqueue(DiamondBlastEvent event) {
    if (!mounted ||
        !widget.enabled ||
        !_foreground ||
        event.roomId != widget.roomId ||
        _seen.contains(event.id) ||
        (_cycle != null && event.cycleStart.isBefore(_cycle!))) {
      return;
    }
    if (_cycle != null && event.cycleStart.isAfter(_cycle!)) {
      _queue.clear();
      _seen.clear();
    }
    _seen.add(event.id);
    if (_seen.length > 200) _seen.remove(_seen.first);
    _cycle = event.cycleStart;
    setState(() {
      // All six threshold animations can be queued in server order.
      if (_queue.length < roomRocketTargets.length) _queue.add(event);
    });
  }

  @override
  void didUpdateWidget(covariant RoomRocketHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId ||
        oldWidget.enabled != widget.enabled) {
      _recoveryTimer?.cancel();
      _recoveryGeneration++;
      _queue.clear();
      _seen.clear();
      _cycle = null;
      if (widget.enabled) _startRecovery();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _recoveryTimer?.cancel();
    _recoveryGeneration++;
    if (!foreground) {
      // Discard queued effects as well as the current clip. Otherwise a
      // completion callback can start another VAP player while backgrounded.
      setState(_queue.clear);
    } else if (widget.enabled) {
      _startRecovery();
      ref.invalidate(roomDiamondStatusProvider(widget.roomId));
    }
  }

  void _finish() {
    if (mounted && _queue.isNotEmpty) {
      setState(() => _queue.removeAt(0));
    }
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    _recoveryGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) {
      ref.listen(roomDiamondStatusProvider(widget.roomId), (previous, next) {
        final cycle = next.valueOrNull?.cycleStart;
        if (cycle != null && _cycle != null && cycle.isAfter(_cycle!)) {
          setState(() {
            _queue.clear();
            _seen.clear();
            _cycle = cycle;
          });
        } else {
          _cycle ??= cycle;
        }
      });
      ref.listen(roomDiamondEventsProvider(widget.roomId), (previous, next) {
        final event = next.valueOrNull?.blast;
        if (event != null) _enqueue(event);
      });
    }
    return Stack(
      children: [
        widget.child,
        if (widget.enabled && _queue.isNotEmpty) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: widget.playbackBuilder?.call(_queue.first, _finish) ??
                  RoomRocketPlayback(
                    key: ValueKey(_queue.first.id),
                    stage: _queue.first.stage,
                    eventId: _queue.first.id,
                    targetCoins: _queue.first.targetCoins,
                    event: _queue.first,
                    onFinished: _finish,
                  ),
            ),
          ),
          Positioned(
            top: 72,
            right: 12,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Skip rocket animation',
                onPressed: _finish,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

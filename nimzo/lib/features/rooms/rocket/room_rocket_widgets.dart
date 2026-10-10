import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/master_ui.dart';
import '../../../core/widgets/reference_widgets.dart';
import '../diamond/room_diamond_repository.dart';
import 'room_rocket_playback.dart';

// Previous cumulative targets remain unchanged. Never rewrite settled gifts.
const roomRocketTargets = diamondTargets;

const _rocketTones = [
  Color(0xff6ae4bb), Color(0xff55c7ee), Color(0xffaf9bff),
  Color(0xffffab75), Color(0xffffd76c), Color(0xffffefa4),
];

class RoomRocketSheet extends ConsumerWidget {
  const RoomRocketSheet({super.key, this.roomId});
  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = roomId;
    final status = id == null ? null : ref.watch(roomDiamondStatusProvider(id));
    final current = status?.valueOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ROOM ROCKET', style: TextStyle(
          fontWeight: FontWeight.w900, fontSize: 20,
          letterSpacing: 1.4,
        )),
        const SizedBox(height: 6),
        const Text('Gift together to launch six rocket levels',
            style: TextStyle(color: NimzoStyle.muted, fontSize: 12)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8, runSpacing: 12, alignment: WrapAlignment.center,
          children: [
            for (var stage = 0; stage < 6; stage++)
              _RocketLevelIcon(
                stage: stage,
                completed: current != null && stage < current.completedStages,
                active: current == null || stage <= current.activeStage,
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (id == null)
          const EmptyContent('Join a room to view Rocket progress.')
        else
          AsyncContent(
            value: status!,
            onRetry: () => ref.invalidate(roomDiamondStatusProvider(id)),
            builder: (state) => Column(
              children: [
                Text(compactNumber(state.totalCoins) + ' gifted in this room today',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: NimzoStyle.line,
                    color: _rocketTones[state.activeStage],
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 10),
                Text(state.completedStages == 6
                  ? 'All six Rocket levels completed!'
                  : 'Rocket ' + (state.activeStage + 1).toString() +
                    ' · ' + compactNumber(roomRocketTargets[state.activeStage]) +
                    ' cumulative coins',
                  textAlign: TextAlign.center),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const Text('Verified gifts only · no extra wallet rewards',
          textAlign: TextAlign.center,
          style: TextStyle(color: NimzoStyle.muted, fontSize: 12)),
        const Text('Daily reset · 11:00 p.m. Saudi time',
          style: TextStyle(color: NimzoStyle.muted, fontSize: 12)),
      ],
    );
  }
}

class _RocketLevelIcon extends StatelessWidget {
  const _RocketLevelIcon({
    required this.stage, required this.completed, required this.active,
  });
  final int stage;
  final bool completed, active;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: active ? 1 : .35,
    duration: const Duration(milliseconds: 220),
    child: SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(alignment: Alignment.center, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xff102a28),
                border: Border.all(color: _rocketTones[stage]),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.rocket_launch,
                  size: 31, color: _rocketTones[stage]),
              ),
            ),
            if (completed) const Positioned(
              right: 0, bottom: 0,
              child: Icon(Icons.check_circle, size: 17,
                color: Color(0xff53db8c)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('L' + (stage + 1).toString(), style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 12,
          )),
          Text(compactNumber(roomRocketTargets[stage]), style: const TextStyle(
            fontSize: 10, color: NimzoStyle.muted,
          )),
        ],
      ),
    ),
  );
}

/// Uses the existing server-settled milestone event stream. The legacy
/// PostgreSQL names remain for old-app compatibility and historical records.
/// Only new room clients render a Rocket effect, never a Diamond burst.
class RoomRocketHost extends ConsumerStatefulWidget {
  const RoomRocketHost({
    super.key, required this.roomId, required this.enabled,
    required this.child, this.playbackBuilder,
  });
  final String roomId;
  final bool enabled;
  final Widget child;
  final Widget Function(DiamondBlastEvent, VoidCallback)? playbackBuilder;

  @override
  ConsumerState<RoomRocketHost> createState() => _RoomRocketHostState();
}

class _RoomRocketHostState extends ConsumerState<RoomRocketHost> {
  final _queue = <DiamondBlastEvent>[];
  final _seen = <String>{};
  DateTime? _cycle;

  @override
  void didUpdateWidget(covariant RoomRocketHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId || !widget.enabled) {
      _queue.clear();
      _seen.clear();
      _cycle = null;
    }
  }

  void _finish() {
    if (mounted && _queue.isNotEmpty) {
      setState(() => _queue.removeAt(0));
    }
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
        if (event == null ||
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
        if (_seen.length > 100) _seen.remove(_seen.first);
        _cycle = event.cycleStart;
        setState(() {
          if (_queue.length < 6) _queue.add(event);
        });
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
                  targetCoins: roomRocketTargets[_queue.first.stage],
                  onFinished: _finish,
                ),
            ),
          ),
          Positioned(
            top: 72, right: 12,
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

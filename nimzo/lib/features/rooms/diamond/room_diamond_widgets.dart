import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/master_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import 'room_diamond_repository.dart';
import 'room_rocket_video.dart';

Color diamondColor(int stage) => const [
      Color(0xff2fc466),
      Color(0xff3390ef),
      Color(0xffff74ac),
      Color(0xffad60ec),
      Color(0xffffba33),
      Color(0xffe0ca83),
    ][stage];

Widget diamondArtwork(int stage, {double size = 48}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          diamondColor(stage).withValues(alpha: .36),
          const Color(0xff09221f),
        ]),
        border: Border.all(color: diamondColor(stage), width: 1.4),
      ),
      child: Icon(Icons.rocket_launch,
          size: size * .63, color: const Color(0xffffe8b1)),
    );

class RoomDiamondSheet extends ConsumerWidget {
  const RoomDiamondSheet({super.key, this.roomId});
  final String? roomId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = roomId;
    final status = id == null ? null : ref.watch(roomDiamondStatusProvider(id));
    final current = status?.valueOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Room Rocket',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var stage = 0; stage < 6; stage++)
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: current == null || stage <= current.activeStage
                          ? 1
                          : .45,
                      child: diamondArtwork(stage),
                    ),
                    Text('L${stage + 1} · ${diamondTargets[stage] ~/ 1000000}M'),
                    if (current != null && stage < current.completedStages)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xff15a35d),
                        size: 16,
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (id == null)
          const EmptyContent('Join a room to view live progress.')
        else
          AsyncContent(
            value: status!,
            onRetry: () => ref.invalidate(roomDiamondStatusProvider(id)),
            builder: (state) => Column(
              children: [
                Text(
                  '${compactNumber(state.totalCoins)} coins gifted today',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.progress,
                  color: diamondColor(state.activeStage),
                  backgroundColor: NimzoStyle.line,
                ),
                const SizedBox(height: 8),
                Text(
                  state.completedStages == 6
                      ? 'All six rockets launched!'
                      : 'Rocket ${state.activeStage + 1} · ${compactNumber(diamondTargets[state.activeStage])} cumulative coins',
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Levels unlock on verified room gifts · no wallet rewards',
          textAlign: TextAlign.center,
          style: TextStyle(color: NimzoStyle.muted, fontSize: 12),
        ),
        const Text(
          'Daily reset: 11:00 p.m. GMT+3',
          style: TextStyle(color: NimzoStyle.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class RoomDiamondHost extends ConsumerStatefulWidget {
  const RoomDiamondHost({
    super.key,
    required this.roomId,
    required this.enabled,
    required this.child,
  });
  final String roomId;
  final bool enabled;
  final Widget child;
  @override
  ConsumerState<RoomDiamondHost> createState() => _RoomDiamondHostState();
}

class _RoomDiamondHostState extends ConsumerState<RoomDiamondHost> {
  final _queue = <DiamondBlastEvent>[];
  final _seen = <String>{};
  DateTime? _cycle;
  @override
  void didUpdateWidget(covariant RoomDiamondHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId || !widget.enabled) {
      _queue.clear();
      _seen.clear();
      _cycle = null;
    }
  }

  void _finish() {
    if (mounted && _queue.isNotEmpty) setState(() => _queue.removeAt(0));
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
            (_cycle != null && event.cycleStart.isBefore(_cycle!))) return;
        if (_cycle != null && event.cycleStart.isAfter(_cycle!)) {
          // A new day's event can arrive before its status RPC completes.
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
        if (_queue.isNotEmpty) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: DiamondBurst(
                key: ValueKey(_queue.first.id),
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
                tooltip: 'Skip room rocket',
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

/// A genuine room gift milestone event. Old Diamond assets are never rendered.
class DiamondBurst extends StatelessWidget {
  const DiamondBurst({
    super.key,
    required this.event,
    required this.onFinished,
  });
  final DiamondBlastEvent event;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => RoomRocketLevelVideo(
        level: event.stage + 1,
        onFinished: onFinished,
      );
}

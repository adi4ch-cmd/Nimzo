// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Index is zero-based, matching the server's verified six-stage event.
String rocketRewardPath(int stage) {
  RangeError.checkValueInInterval(stage, 0, 5, 'stage');
  return 'assets/room_rocket/vap_rocket_reward_' +
      (stage + 1).toString() + '.mp4';
}

String rocketFlyPath(int stage) {
  RangeError.checkValueInInterval(stage, 0, 5, 'stage');
  return 'assets/room_rocket/vap_rocket_fly_' +
      (stage + 1).toString() + '.mp4';
}

/// Original videos have the VAP metadata box and alpha mask. A normal MP4
/// widget will show the mask instead of compositing transparency.
class RoomRocketPlayback extends StatefulWidget {
  const RoomRocketPlayback({
    super.key,
    required this.stage,
    required this.targetCoins,
    required this.onFinished,
  });

  final int stage, targetCoins;
  final VoidCallback onFinished;

  @override
  State<RoomRocketPlayback> createState() => _RoomRocketPlaybackState();
}

class _RoomRocketPlaybackState extends State<RoomRocketPlayback>
    with WidgetsBindingObserver {
  VapPlayerController? _player;
  StreamSubscription<VapEvent>? _events;
  Timer? _watchdog;
  bool _finished = false;
  bool _unavailable = false;
  int _part = 0; // 0: rocket launch; 1: achieved-level reward

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _watchdog?.cancel();
    widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchdog = Timer(const Duration(seconds: 16), _finish);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      // Require both Haza clips for a stage, no fabricated single-video effect.
      final reward = rocketRewardPath(widget.stage);
      final fly = rocketFlyPath(widget.stage);
      if (!manifest.listAssets().contains(reward) ||
          !manifest.listAssets().contains(fly)) {
        if (mounted) {
          setState(() => _unavailable = true);
          _watchdog?.cancel();
          _watchdog = Timer(const Duration(milliseconds: 900), _finish);
        }
        return;
      }
      await _playSegment(fly);
    } catch (_) {
      if (mounted) {
        setState(() => _unavailable = true);
        _watchdog?.cancel();
        _watchdog = Timer(const Duration(milliseconds: 900), _finish);
      }
    }
  }

  Future<void> _playSegment(String path) async {
    // Play original 1.5s lift-off, followed by the matching 10s reward.
    // Native players must never overlap or compete with Vivox audio.
    await _events?.cancel();
    _events = null;
    final previous = _player;
    _player = null;
    if (previous != null) await previous.dispose();
    if (!mounted || _finished) return;
    final controller = VapPlayerController.asset(
      path,
      options: const VapPlayerOptions(
        viewType: VapViewType.textureView,
        scaleType: VapScaleType.fitCenter,
        repeatCount: 0,
        mute: true,
      ),
    );
    _player = controller;
    _events = controller.events.listen(
      (event) {
        if (_finished) return;
        if (event is VapErrorEvent) {
          _finish();
        } else if (event is VapCompletedEvent) {
          if (_part == 0) {
            _part = 1;
            unawaited(_playSegment(rocketRewardPath(widget.stage)));
          } else {
            _finish();
          }
        }
      },
      onError: (Object _) => _finish(),
    );
    await controller.initialize();
    if (!mounted || _finished) return;
    setState(() {});
    await controller.play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No delayed fireworks after users return from another application.
    if (state != AppLifecycleState.resumed) _finish();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events?.cancel());
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              if (!_unavailable && _player != null)
                Positioned.fill(child: IgnorePointer(
                  child: VapPlayer(_player!),
                )),
              if (_unavailable)
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xff132b24),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Rocket level reached. Video media unavailable.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 22,
                left: 22,
                right: 22,
                child: IgnorePointer(
                  child: Text(
                    'NIMZO ROOM ROCKET  ' +
                        (widget.stage + 1).toString() +
                        ' / 6',
                    style: const TextStyle(
                      color: Color(0xffffdd83),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

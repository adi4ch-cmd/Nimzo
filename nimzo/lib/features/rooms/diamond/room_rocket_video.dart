import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:video_player/video_player.dart';

/// One room gifting milestone: a short launch, followed by its own reward.
/// The supplied Haza VAP clips contain RGB on the LEFT half and a separate
/// alpha mask on the RIGHT half. Ordinary VideoPlayer cannot combine that
/// alpha, so this player CROPS the mask and presents the RGB half on a dark
/// cinematic stage. It does not claim to implement transparent VAP compositing.
class RoomRocketLevelVideo extends StatefulWidget {
  const RoomRocketLevelVideo({
    super.key,
    required this.level,
    required this.onFinished,
  }) : assert(level >= 1 && level <= 6);

  final int level;
  final VoidCallback onFinished;

  @override
  State<RoomRocketLevelVideo> createState() => _RoomRocketLevelVideoState();
}

class _RoomRocketLevelVideoState extends State<RoomRocketLevelVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  Timer? _watchdog;
  bool _completed = false, _isReward = false, _mediaAvailable = false;
  int _sequence = 0;

  static String videoAsset(int level, {required bool reward}) =>
      'assets/room_rocket/vap_rocket_${reward ? 'reward' : 'fly'}_$level.mp4';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start(reward: false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _video?.pause();
      _finish();
    }
  }

  Future<void> _start({required bool reward}) async {
    if (_completed || !mounted) return;
    final generation = ++_sequence;
    _watchdog?.cancel();
    final previous = _video;
    _video = null;
    if (previous != null) {
      previous.removeListener(_onTick);
      await previous.dispose();
    }
    if (!mounted || _completed || generation != _sequence) return;
    setState(() {
      _isReward = reward;
      _mediaAvailable = false;
    });
    final name = videoAsset(widget.level, reward: reward);
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(name)) {
        if (!reward) {
          unawaited(_start(reward: true));
        } else {
          _showMissingMedia();
        }
        return;
      }
      final controller = VideoPlayerController.asset(name);
      await controller.initialize();
      if (!mounted || _completed || generation != _sequence) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(0);
      _video = controller;
      controller.addListener(_onTick);
      setState(() => _mediaAvailable = true);
      _watchdog = Timer(
        reward ? const Duration(seconds: 13) : const Duration(seconds: 3),
        () => unawaited(_advance()),
      );
      await controller.play();
    } catch (_) {
      if (!mounted || _completed || generation != _sequence) return;
      if (!reward) {
        unawaited(_start(reward: true));
      } else {
        _showMissingMedia();
      }
    }
  }

  void _showMissingMedia() {
    if (!mounted || _completed) return;
    setState(() => _mediaAvailable = false);
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(milliseconds: 2200), _finish);
  }

  void _onTick() {
    final player = _video;
    if (_completed || player == null || !player.value.isInitialized) return;
    final value = player.value;
    if (value.hasError) {
      unawaited(_advance());
      return;
    }
    if (value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 120)) {
      unawaited(_advance());
    }
  }

  Future<void> _advance() async {
    if (_completed || !mounted) return;
    _watchdog?.cancel();
    // Mark this generation consumed to prevent both an end event and the
    // watchdog advancing twice.
    _sequence++;
    if (_isReward) {
      _finish();
    } else {
      await _start(reward: true);
    }
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _watchdog?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _completed = true;
    _watchdog?.cancel();
    final previous = _video;
    if (previous != null) {
      previous.removeListener(_onTick);
      unawaited(previous.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: const Color(0xe8000a12)),
            if (_mediaAvailable && _video != null)
              Center(
                child: LayoutBuilder(builder: (context, box) {
                  // VAP RGB is the first 568 px of a 1136 px-wide file.
                  // Reward videos: 568x1632; launch videos: 568x752.
                  final hOverW = _isReward ? 1632 / 568 : 752 / 568;
                  final visibleWidth = math.min(
                    math.min(box.maxWidth, width) * .96,
                    box.maxHeight * .91 / hOverW,
                  );
                  final visibleHeight = visibleWidth * hOverW;
                  return SizedBox(
                    width: visibleWidth,
                    height: visibleHeight,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: visibleWidth * 2,
                        maxWidth: visibleWidth * 2,
                        minHeight: visibleHeight,
                        maxHeight: visibleHeight,
                        child: SizedBox(
                          width: visibleWidth * 2,
                          height: visibleHeight,
                          child: VideoPlayer(_video!),
                        ),
                      ),
                    ),
                  );
                }),
              )
            else
              const Center(
                child: Icon(Icons.rocket_launch,
                    size: 132, color: Color(0xffe9c77a)),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 38,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ROOM ROCKET · LEVEL ${widget.level}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xffffdf8a),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      )),
                  const SizedBox(height: 5),
                  Text(
                    !_mediaAvailable && _isReward
                        ? 'Rocket video pending local asset installation'
                        : 'Unlocked through verified room gifts',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_vap_player/flutter_vap_player.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/providers/supabase_provider.dart';
import 'room_rocket_top_sender.dart';

/// Index is zero-based, matching the server's verified six-stage event.
String rocketRewardPath(int stage) {
  RangeError.checkValueInInterval(stage, 0, 5, 'stage');
  return 'assets/room_rocket/vap_rocket_reward_' +
      (stage + 1).toString() +
      '.mp4';
}

String rocketFlyPath(int stage) {
  RangeError.checkValueInInterval(stage, 0, 5, 'stage');
  return 'assets/room_rocket/vap_rocket_fly_' + (stage + 1).toString() + '.mp4';
}

/// ffprobe audit: all fly clips and rewards 1–3 have no audio track.
/// Rewards 4–6 retain their original embedded AAC, without a second soundtrack.
String? rocketSoundPath(int stage, {required bool reward}) {
  RangeError.checkValueInInterval(stage, 0, 5, 'stage');
  if (reward && stage >= 3) return null;
  return reward
      ? 'assets/room_rocket/nimzo_rocket_reward.wav'
      : 'assets/room_rocket/nimzo_rocket_launch.wav';
}

/// Original videos have the VAP metadata box and alpha mask. A normal MP4
/// widget will show the mask instead of compositing transparency.
class RoomRocketPlayback extends ConsumerStatefulWidget {
  const RoomRocketPlayback({
    super.key,
    required this.stage,
    this.eventId,
    required this.targetCoins,
    required this.onFinished,
  });

  final int stage, targetCoins;
  final String? eventId;
  final VoidCallback onFinished;

  @override
  ConsumerState<RoomRocketPlayback> createState() => _RoomRocketPlaybackState();
}

class _RoomRocketPlaybackState extends ConsumerState<RoomRocketPlayback>
    with WidgetsBindingObserver {
  VapPlayerController? _player;
  AudioPlayer? _soundPlayer;
  Timer? _soundLoadTimer;
  Completer<void>? _soundLoadWait;
  bool _soundUnavailable = false;
  StreamSubscription<VapEvent>? _events;
  Timer? _watchdog;
  bool _finished = false;
  bool _unavailable = false;
  bool _initialized = false;
  int _part = 0; // 0: rocket launch; 1: achieved-level reward

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _watchdog?.cancel();
    unawaited(_stopSound());
    widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchdog = Timer(const Duration(seconds: 20), _playbackFailed);
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
        _playbackFailed();
        return;
      }
      await _playSegment(fly);
    } catch (_) {
      _playbackFailed();
    }
  }

  String? _winnerAvatarUrl(RocketTopSender? sender) {
    final path = sender?.avatarPath;
    if (path == null || path.isEmpty) return null;
    return ref
        .read(supabaseProvider)
        .storage
        .from('avatars')
        .getPublicUrl(path);
  }

  Future<Uint8List?> _loadSenderImage() async {
    final id = widget.eventId;
    if (id == null) return null;
    try {
      final sender = await ref
          .read(roomRocketTopSenderProvider(id).future)
          .timeout(const Duration(seconds: 3));
      final url = _winnerAvatarUrl(sender);
      if (url == null) return null;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      try {
        final req = await client.getUrl(Uri.parse(url));
        final response = await req.close().timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) return null;
        final bytes = BytesBuilder(copy: false);
        await for (final chunk
            in response.timeout(const Duration(seconds: 3))) {
          bytes.add(chunk);
          if (bytes.length > 2 * 1024 * 1024) return null;
        }
        return bytes.takeBytes();
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _stopSound() async {
    _soundLoadTimer?.cancel();
    final loading = _soundLoadWait;
    _soundLoadWait = null;
    if (loading != null && !loading.isCompleted) loading.complete();
    try {
      await _soundPlayer?.stop();
    } catch (_) {/* Already disposed. */}
  }

  Future<void> _prepareSound() async {
    await _stopSound();
    final asset = rocketSoundPath(widget.stage, reward: _part == 1);
    if (asset == null || !mounted || _finished) return;
    try {
      // Vivox owns the room audio session. Do not request audio focus or
      // replace its voice-chat audio attributes to play a short effect.
      final player = _soundPlayer ??= AudioPlayer(
        handleAudioSessionActivation: false,
        handleInterruptions: false,
        androidApplyAudioAttributes: false,
      );
      final loading = Completer<void>();
      _soundLoadWait = loading;
      _soundLoadTimer = Timer(const Duration(seconds: 3), () {
        if (!loading.isCompleted)
          loading.completeError(TimeoutException('Rocket sound preload'));
      });
      unawaited(player.setAsset(asset).then<void>((_) {
        if (!loading.isCompleted) loading.complete();
      }, onError: (Object error, StackTrace stack) {
        if (!loading.isCompleted) loading.completeError(error, stack);
      }));
      try {
        await loading.future;
      } finally {
        if (identical(_soundLoadWait, loading)) {
          _soundLoadTimer?.cancel();
          _soundLoadWait = null;
        }
      }
    } catch (_) {
      if (mounted && !_finished) setState(() => _soundUnavailable = true);
    }
  }

  Future<void> _playSound(VapPlayerController controller) async {
    if (_soundUnavailable ||
        !mounted ||
        _finished ||
        _player != controller ||
        rocketSoundPath(widget.stage, reward: _part == 1) == null) return;
    try {
      await _soundPlayer?.play();
    } catch (_) {
      if (mounted && !_finished) setState(() => _soundUnavailable = true);
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
    await _prepareSound();
    if (!mounted || _finished) return;
    final controller = VapPlayerController.asset(
      path,
      options: VapPlayerOptions(
        viewType: VapViewType.textureView,
        scaleType: VapScaleType.fitCenter,
        repeatCount: 0,
        // Preserve the original Rocket 4–6 AAC audio where present.
        mute: false,
        resourceDelegate: VapResourceDelegate(
          resolveText: (resource) async {
            if (widget.eventId == null) return null;
            try {
              final sender = await ref.read(
                roomRocketTopSenderProvider(widget.eventId!).future,
              );
              return sender?.name;
            } catch (_) {
              return null;
            }
          },
          resolveImage: (resource) => _loadSenderImage(),
        ),
      ),
    );
    _player = controller;
    if (mounted) setState(() => _initialized = false);
    _events = controller.events.listen(
      (event) {
        if (_finished) return;
        if (event is VapStartedEvent) {
          // Start the preloaded effect on the native VAP started event.
          unawaited(_playSound(controller));
        } else if (event is VapErrorEvent) {
          _playbackFailed();
        } else if (event is VapCompletedEvent) {
          if (_part == 0) {
            _part = 1;
            unawaited(_playSegment(rocketRewardPath(widget.stage))
                .catchError((Object _) => _playbackFailed()));
          } else {
            _finish();
          }
        }
      },
      onError: (Object _) => _playbackFailed(),
    );
    await controller.initialize();
    if (!mounted || _finished) return;
    setState(() => _initialized = true);
    await controller.play();
  }

  void _playbackFailed() {
    if (!mounted || _finished) return;
    unawaited(_stopSound());
    setState(() => _unavailable = true);
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 3), _finish);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No delayed fireworks after users return from another application.
    if (state != AppLifecycleState.resumed) _finish();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _soundLoadTimer?.cancel();
    final loading = _soundLoadWait;
    _soundLoadWait = null;
    if (loading != null && !loading.isCompleted) loading.complete();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events?.cancel());
    final player = _player;
    if (player != null) unawaited(player.dispose());
    final sound = _soundPlayer;
    _soundPlayer = null;
    if (sound != null) unawaited(sound.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              if (!_unavailable && _player != null && _initialized)
                Positioned.fill(
                    child: IgnorePointer(
                  child: VapPlayer(_player!),
                )),
              if (_part == 1 && widget.eventId != null)
                Positioned(
                  top: MediaQuery.sizeOf(context).height * .12,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: ref
                          .watch(
                            roomRocketTopSenderProvider(widget.eventId!),
                          )
                          .maybeWhen(
                            data: (sender) {
                              final avatar = _winnerAvatarUrl(sender);
                              if (sender == null || avatar == null) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                key: const ValueKey('rocket-blast-top1-avatar'),
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xffffd76c), width: 3),
                                  image: DecorationImage(
                                      image: NetworkImage(avatar),
                                      fit: BoxFit.cover),
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                    ),
                  ),
                ),
              if (_soundUnavailable && !_unavailable)
                const Positioned(
                  bottom: 64,
                  left: 22,
                  right: 22,
                  child: IgnorePointer(
                      child: Text(
                    'Rocket sound unavailable on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  )),
                ),
              if (!_unavailable && !_initialized)
                const Center(child: CircularProgressIndicator()),
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
                        'Rocket reached, but VAP playback failed on this device.',
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

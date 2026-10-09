import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays an actual licensed MP4 asset, not a static artwork animation.
///
/// Caller must supply a trusted HTTPS URL or a bundled Flutter asset path.
/// Only show this after the server has confirmed gift settlement.
class GiftVideoOverlay extends StatefulWidget {
  const GiftVideoOverlay({
    super.key,
    required this.source,
    required this.sender,
    required this.recipient,
    required this.giftName,
    required this.onFinished,
    this.muted = false,
  });

  final String source;
  final String sender;
  final String recipient;
  final String giftName;
  final VoidCallback onFinished;
  final bool muted;

  @override
  State<GiftVideoOverlay> createState() => _GiftVideoOverlayState();
}

class _GiftVideoOverlayState extends State<GiftVideoOverlay> {
  VideoPlayerController? _controller;
  bool _finished = false;
  String? _error;
  Timer? _watchdog;
  late bool _muted;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _watchdog = Timer(const Duration(seconds: 15), _finish);
    _start();
  }

  Future<void> _start() async {
    final source = widget.source.trim();
    final uri = Uri.tryParse(source);
    if (!source.startsWith('assets/') &&
        (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
      if (mounted && !_finished) {
        setState(() => _error = 'Invalid gift video source');
      }
      scheduleMicrotask(_finish);
      return;
    }
    if (!mounted || _finished) return;
    final controller = source.startsWith('assets/')
        ? VideoPlayerController.asset(
            source,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.networkUrl(
            uri!,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
    _controller = controller;
    controller.addListener(_onPlaybackChanged);
    try {
      await controller.initialize();
      if (!mounted || _finished) return;
      // Allow the original clip to finish; still recover from a stalled decoder.
      _watchdog?.cancel();
      final seconds = (controller.value.duration.inSeconds + 3).clamp(3, 120);
      _watchdog = Timer(Duration(seconds: seconds), _finish);
      await controller.setLooping(false);
      if (!mounted || _finished) return;
      await controller.setVolume(_muted ? 0 : 0.65);
      if (!mounted || _finished) return;
      await controller.play();
      if (mounted && !_finished) setState(() {});
    } catch (_) {
      if (mounted && !_finished) {
        setState(() => _error = 'Gift video unavailable');
        _finish();
      }
    }
  }

  void _onPlaybackChanged() {
    final controller = _controller;
    if (controller == null || _finished || !mounted) return;
    final state = controller.value;
    if (state.hasError) {
      setState(() => _error = 'Gift video unavailable');
      _finish();
      return;
    }
    if (state.isInitialized &&
        !state.isPlaying &&
        state.position >= state.duration &&
        state.duration > Duration.zero) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlaybackChanged);
      unawaited(controller.pause().catchError((Object _) {}));
    }
    if (mounted) widget.onFinished();
  }

  Future<void> _updateSound() async {
    try {
      await _controller?.setVolume(_muted ? 0 : 0.65);
    } catch (_) {
      if (mounted) _finish();
    }
  }

  @override
  void didUpdateWidget(covariant GiftVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_finished && oldWidget.muted != widget.muted) {
      _muted = widget.muted;
      unawaited(_updateSound());
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _controller?.removeListener(_onPlaybackChanged);
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              IgnorePointer(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.94,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                    ),
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              )
            else
              IgnorePointer(
                child: Center(
                  child: Text(
                    _error ?? 'Loading gift animation…',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: _finish,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close gift animation',
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: _finished
                    ? null
                    : () {
                        setState(() => _muted = !_muted);
                        unawaited(_updateSound());
                      },
                icon: Icon(
                  _muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                tooltip: _muted ? 'Enable gift sound' : 'Mute gift sound',
              ),
            ),
            Positioned(
              bottom: 28,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDB65E)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${widget.sender} sent ${widget.giftName} to ${widget.recipient}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

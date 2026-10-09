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

  @override
  void initState() {
    super.initState();
    _watchdog = Timer(const Duration(seconds: 30), _finish);
    _start();
  }

  Future<void> _start() async {
    final source = widget.source.trim();
    final uri = Uri.tryParse(source);
    if (!source.startsWith('assets/') &&
        (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
      setState(() => _error = 'Invalid gift video source');
      _finish();
      return;
    }
    final controller = source.startsWith('assets/')
        ? VideoPlayerController.asset(source)
        : VideoPlayerController.networkUrl(uri!);
    _controller = controller;
    controller.addListener(_onPlaybackChanged);
    try {
      await controller.initialize();
      if (!mounted || _finished) return;
      await controller.setLooping(false);
      await controller.setVolume(widget.muted ? 0 : 0.65);
      await controller.play();
      if (mounted) setState(() {});
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
    widget.onFinished();
  }

  @override
  void didUpdateWidget(covariant GiftVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 0.65);
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              Center(
                child: Text(
                  _error ?? 'Loading gift animation…',
                  style: const TextStyle(color: Colors.white),
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
              bottom: 28,
              left: 16,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
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
          ],
        ),
      ),
    );
  }
}

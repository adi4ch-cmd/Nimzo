import '../../core/services/approved_media_bytes.dart';
import '../../core/services/verified_media_file.dart';
import 'dart:async';
import 'dart:math' as math;

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
    this.publication,
  });

  final String source;
  final String sender;
  final String recipient;
  final String giftName;
  final VoidCallback onFinished;
  final bool muted;
  final ApprovedMediaPublication? publication;

  @override
  State<GiftVideoOverlay> createState() => _GiftVideoOverlayState();
}

class _GiftVideoOverlayState extends State<GiftVideoOverlay> {
  VideoPlayerController? _controller;
  VerifiedMediaFile? _verifiedFile;
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
    if (!source.startsWith('assets/') && widget.publication != null) {
      try {
        final verified =
            await VerifiedMediaFile.create(source, widget.publication!);
        if (!mounted || _finished) {
          await verified.dispose();
          return;
        }
        _verifiedFile = verified;
      } catch (_) {
        if (mounted && !_finished)
          setState(() => _error = 'Gift video could not be verified');
        _finish();
        return;
      }
    }
    final controller = _verifiedFile != null
        ? VideoPlayerController.file(_verifiedFile!.file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
        : source.startsWith('assets/')
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
    final file = _verifiedFile;
    if (controller != null) {
      unawaited(controller.dispose().whenComplete(() async {
        await file?.dispose();
      }));
    } else {
      unawaited(file?.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final size = MediaQuery.sizeOf(context);
    final ready = controller != null && controller.value.isInitialized;
    final aspect = ready && controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 9 / 16;

    // A portrait MP4 is opaque video, not a transparent flying effect.
    // Keep the complete original frame but avoid covering an entire live room,
    // its ten mic seats, chat composer, and interaction controls.
    final maxVideoHeight =
        size.height * (size.height >= size.width ? .48 : .58);
    final maxVideoWidth = size.width * .78;
    final videoHeight = math.min(maxVideoHeight, maxVideoWidth / aspect);
    final videoWidth = videoHeight * aspect;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10151E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE4BA67),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCF9F45)
                                  .withValues(alpha: .28),
                              blurRadius: 25,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: ready
                                ? VideoPlayer(controller)
                                : ColoredBox(
                                    color: const Color(0xFF10151E),
                                    child: Center(
                                      child: Text(
                                        _error ?? 'Loading gift animation…',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _control(
                            icon: _muted ? Icons.volume_off : Icons.volume_up,
                            tooltip: _muted
                                ? 'Enable gift sound'
                                : 'Mute gift sound',
                            onPressed: _finished
                                ? null
                                : () {
                                    setState(() => _muted = !_muted);
                                    unawaited(_updateSound());
                                  },
                          ),
                          const SizedBox(width: 4),
                          _control(
                            icon: Icons.close,
                            tooltip: 'Close gift animation',
                            onPressed: _finish,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IgnorePointer(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(size.width * .84, 360),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF15181F).withValues(alpha: .87),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE4BA67).withValues(alpha: .76),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: Text(
                        '${widget.sender} sent ${widget.giftName} to ${widget.recipient}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _control({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        iconSize: 19,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xBB11141D),
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
      ),
    );
  }
}

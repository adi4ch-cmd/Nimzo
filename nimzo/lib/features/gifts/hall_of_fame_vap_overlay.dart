import '../../core/services/approved_media_bytes.dart';
import '../../core/services/verified_media_file.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// A settled Hall of Fame gift rendered by Tencent VAP RGB + Alpha playback.
/// Unlike VideoPlayer, VAP composites the alpha channel over the live room.
/// [source] MUST be an admin-approved HTTPS MP4 with an embedded vapc atom.
class HallOfFameVapOverlay extends StatefulWidget {
  const HallOfFameVapOverlay({
    super.key,
    required this.source,
    required this.sender,
    required this.recipient,
    required this.quantity,
    required this.onFinished,
    this.giftName = 'Hall of Fame',
    this.publication,
    this.muted = false,
  });

  final String source, sender, recipient, giftName;
  final int quantity;
  final VoidCallback onFinished;
  final ApprovedMediaPublication? publication;
  final bool muted;

  @override
  State<HallOfFameVapOverlay> createState() => _HallOfFameVapOverlayState();
}

class _HallOfFameVapOverlayState extends State<HallOfFameVapOverlay> {
  VapPlayerController? _controller;
  VerifiedMediaFile? _verifiedFile;
  StreamSubscription<dynamic>? _events;
  Timer? _watchdog;
  bool _ready = false;
  String? _failure;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _watchdog =
        Timer(const Duration(seconds: 35), () => _fail('Gift video timed out'));
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (!ApprovedMediaBytes.isSafeUrl(widget.source)) {
        _fail('Gift video URL is invalid');
        return;
      }
      if (widget.publication != null) {
        final file =
            await VerifiedMediaFile.create(widget.source, widget.publication!);
        if (!mounted || _finished) {
          await file.dispose();
          return;
        }
        _verifiedFile = file;
      }
      if (!mounted || _finished) return;
      final options = VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.centerCrop,
          repeatCount: 0,
          mute: widget.muted);
      final controller = _verifiedFile != null
          ? VapPlayerController.file(_verifiedFile!.file, options: options)
          : VapPlayerController.networkUrl(Uri.parse(widget.source),
              options: options);
      _controller = controller;
      _events = controller.events.listen((event) {
        if (event is VapCompletedEvent) _finish();
        if (event is VapErrorEvent) _fail('Native VAP player failed');
      }, onError: (Object _) => _fail('Native VAP event stream error'));
      await _start();
    } catch (_) {
      _fail('VAP media could not be verified');
    }
  }

  Future<void> _start() async {
    try {
      final controller = _controller;
      if (controller == null) return;
      await controller.initialize();
      if (!mounted || _finished) return;
      setState(() => _ready = true);
      // Use the audio track multiplexed into the approved VAP MP4.
      // A Flutter-only fallback should never expose the packed alpha as video.
      await controller.play();
    } catch (_) {
      _fail('VAP initialization or network playback failed');
    }
  }

  void _fail(String reason) {
    if (_finished || !mounted || _failure != null) return;
    setState(() => _failure = reason);
    _watchdog?.cancel();
    // Keep the diagnostic visible so QA can capture a screenshot, without
    // blocking the room forever. No new gift transaction is attempted.
    _watchdog = Timer(const Duration(seconds: 8), _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    unawaited(_events?.cancel());
    final controller = _controller;
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
    // The host already inserts this widget as a full-room Positioned.fill.
    // Rendering in a nested 92% x 75% box used to shrink the actual gift into
    // the centre of the screen. Keep the texture edge-to-edge; centerCrop
    // preserves the gift's aspect ratio while filling the viewport.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _failure != null
                  ? Center(
                      child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: const Color(0xdd24152b),
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'Gift animation could not play: $_failure\\n'
                          'No additional coins charged by playback.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ))
                  : _ready
                      ? SizedBox.expand(child: VapPlayer(_controller!))
                      : const Center(
                          child: Text(
                            'Loading gift animation…',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Close gift animation',
                onPressed: _finish,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xbb20182a),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xffe5bb64)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '${widget.sender} sent ${widget.giftName} × ${widget.quantity} to ${widget.recipient}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xffffe7ad),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

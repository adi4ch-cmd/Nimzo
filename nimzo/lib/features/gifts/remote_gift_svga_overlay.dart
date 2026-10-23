import '../../core/services/renderable_media.dart';
import '../../core/services/approved_media_bytes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

/// Plays an approved, network-hosted SVGA only after a settled server gift.
/// Caps download size and time, rejects HTTP redirects and never charges coins.
class RemoteGiftSvgaOverlay extends StatefulWidget {
  const RemoteGiftSvgaOverlay({
    super.key,
    required this.source,
    required this.giftName,
    required this.sender,
    required this.recipient,
    required this.quantity,
    required this.onFinished,
    this.publication,
    this.soundEnabled = false,
  });

  final String source, giftName, sender, recipient;
  final int quantity;
  final VoidCallback onFinished;
  final ApprovedMediaPublication? publication;
  final bool soundEnabled;

  @override
  State<RemoteGiftSvgaOverlay> createState() => _RemoteGiftSvgaOverlayState();
}

class _RemoteGiftSvgaOverlayState extends State<RemoteGiftSvgaOverlay>
    with SingleTickerProviderStateMixin {
  static const maxBytes = 32 * 1024 * 1024;
  late final SVGAAnimationController _controller;
  Timer? _watchdog;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this)
      ..muted = !widget.soundEnabled;
    _watchdog = Timer(const Duration(seconds: 35), _finish);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final verifiedBytes = await ApprovedMediaBytes.fetch(widget.source,
          publication: widget.publication, maxBytes: maxBytes);
      if (!mounted || _finished) return;
      if (widget.publication != null)
        await validateRenderableMedia(verifiedBytes, widget.publication!);
      final movie = await SVGAParser.shared.decodeFromBuffer(
        verifiedBytes,
      );
      if (!mounted || _finished) {
        movie.dispose();
        return;
      }
      _controller.videoItem = movie;
      setState(() {});
      await _controller.forward();
      _finish();
    } catch (_) {
      if (!mounted || _finished) return;
      setState(() => _error = 'Approved animation could not play');
      _finish();
    } finally {}
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black.withValues(alpha: .60)),
              if (_controller.videoItem != null)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width,
                      maxHeight: MediaQuery.sizeOf(context).height * .82,
                    ),
                    child: SVGAImage(_controller),
                  ),
                )
              else
                Center(
                    child: Text(_error ?? 'Loading approved gift animation…',
                        style: const TextStyle(color: Colors.white))),
              Positioned(
                right: 12,
                top: 12,
                child: IconButton(
                  tooltip: 'Skip gift animation',
                  onPressed: _finish,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xbb24152b),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${widget.sender} sent ${widget.giftName} × ${widget.quantity} to ${widget.recipient}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
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

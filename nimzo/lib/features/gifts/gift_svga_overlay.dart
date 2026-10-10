import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

/// Only these two real, byte-verified, MIT-repository SVGA animations have
/// a corresponding live NIMZO gift. Never substitute an unrelated animation.
const freeGiftAnimationsById = <String, String>{
  '99faac6c-933c-4c08-8026-08c39227751e':
      'assets/gifts/free/rocket.svga',
  '35e4c570-cb02-4466-ae86-d670b3fb05ab':
      'assets/gifts/free/sports_car.svga',
};

const freeGiftAnimationsByName = <String, String>{
  'rocket': 'assets/gifts/free/rocket.svga',
  'sports car': 'assets/gifts/free/sports_car.svga',
};

String? freeGiftAnimationForId(String id) => freeGiftAnimationsById[id];

String? freeGiftAnimationForName(String name) =>
    freeGiftAnimationsByName[name.trim().toLowerCase()];

/// Animation plays ONCE, after the backend has settled a gift, then advances
/// the room playback queue. The source is local and pinned to a real gift ID.
class FreeGiftSvgaOverlay extends StatefulWidget {
  const FreeGiftSvgaOverlay({
    super.key,
    required this.source,
    required this.giftName,
    required this.sender,
    required this.recipient,
    required this.quantity,
    required this.onFinished,
  });

  final String source, giftName, sender, recipient;
  final int quantity;
  final VoidCallback onFinished;

  @override
  State<FreeGiftSvgaOverlay> createState() => _FreeGiftSvgaOverlayState();
}

class _FreeGiftSvgaOverlayState extends State<FreeGiftSvgaOverlay>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller;
  Timer? _watchdog;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    // The original demo animation may include sound. Never interrupt a
    // Vivox conversation; room voice remains primary and always audible.
    _controller.muted = true;
    _watchdog = Timer(const Duration(seconds: 25), _finish);
    unawaited(_play());
  }

  Future<void> _play() async {
    try {
      final item = await SVGAParser.shared.decodeFromAssets(widget.source);
      if (!mounted || _done) {
        item.dispose();
        return;
      }
      _controller.videoItem = item;
      setState(() {});
      await _controller.forward();
      if (mounted) _finish();
    } catch (_) {
      if (!mounted || _done) return;
      setState(() => _error = 'Animation unavailable');
      _finish();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
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
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: .72)),
            if (_controller.videoItem != null)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width,
                    maxHeight: MediaQuery.sizeOf(context).height * .72,
                  ),
                  child: SVGAImage(_controller),
                ),
              )
            else
              Center(
                child: Text(
                  _error ?? 'Loading original gift animation…',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Positioned(
              top: 12,
              right: 14,
              child: IconButton(
                tooltip: 'Skip gift animation',
                onPressed: _finish,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 26,
              left: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xee10251e),
                  border: Border.all(color: const Color(0xff80d6ad)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    widget.sender + ' sent ' + widget.giftName +
                        ' × ' + widget.quantity.toString() +
                        ' to ' + widget.recipient,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Renderer for accepted, bundled VAP-v2 media after server settlement.
///
/// This component grants no gifting/payment authority. Callers must pass the
/// verified event identity and metadata. It is not yet enabled in live routing:
/// licensed six-gift media and native Android/Vivox acceptance are still pending.
class GiftVapOverlay extends StatelessWidget {
  const GiftVapOverlay({
    super.key,
    required this.eventId,
    required this.assetPath,
    required this.sender,
    required this.recipient,
    required this.giftName,
    required this.quantity,
    required this.settledCoins,
    required this.onFinished,
    this.onUnavailable,
  })  : assert(quantity > 0),
        assert(settledCoins > 0);

  final String eventId, assetPath, sender, recipient, giftName;
  final int quantity, settledCoins;
  final VoidCallback onFinished;
  final VoidCallback? onUnavailable;

  @override
  Widget build(BuildContext context) => _GiftVapPlayback(
        key: ValueKey((eventId, assetPath)),
        gift: this,
      );
}

class _GiftVapPlayback extends StatefulWidget {
  const _GiftVapPlayback({super.key, required this.gift});
  final GiftVapOverlay gift;
  @override
  State<_GiftVapPlayback> createState() => _GiftVapPlaybackState();
}

class _GiftVapPlaybackState extends State<_GiftVapPlayback>
    with WidgetsBindingObserver {
  VapPlayerController? _controller;
  StreamSubscription<VapEvent>? _events;
  Timer? _watchdog;
  bool _done = false;
  GiftVapOverlay get gift => widget.gift;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchdog = Timer(const Duration(seconds: 8), () => _finish(failed: true));
    unawaited(_start());
  }

  Future<void> _start() async {
    final path = gift.assetPath;
    // The package's network cache has no download-size limit. Use approved
    // bundled assets here; remote downloads need a separately bounded cache.
    if (!path.startsWith('assets/gifts/') ||
        !path.endsWith('.mp4') ||
        path.split('/').contains('..')) {
      scheduleMicrotask(() => _finish(failed: true));
      return;
    }
    final player = VapPlayerController.asset(
      path,
      options: const VapPlayerOptions(
        viewType: VapViewType.textureView,
        scaleType: VapScaleType.fitCenter,
        repeatCount: 0,
        mute: true,
      ),
    );
    _controller = player;
    _events = player.events.listen((event) {
      if (event is VapErrorEvent) {
        _finish(failed: true);
      } else if (event is VapCompletedEvent) {
        _finish();
      }
    }, onError: (Object _) => _finish(failed: true));
    try {
      await player.initialize();
      if (!mounted || _done) return;
      _watchdog?.cancel();
      // Accepted clips are 8–12 seconds. Recover from a missing completion.
      _watchdog =
          Timer(const Duration(seconds: 15), () => _finish(failed: true));
      setState(() {});
      await player.play();
    } catch (_) {
      _finish(failed: true);
    }
  }

  void _finish({bool failed = false}) {
    if (_done || !mounted) return;
    _done = true;
    _watchdog?.cancel();
    unawaited(_release());
    if (failed && gift.onUnavailable != null) {
      gift.onUnavailable!();
    } else {
      gift.onFinished();
    }
  }

  Future<void> _release() async {
    final events = _events;
    final player = _controller;
    _events = null;
    _controller = null;
    try {
      await events?.cancel();
    } catch (_) {
      // Always attempt native cleanup even if event cancellation fails.
    }
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {
        // Decoder cleanup cannot block leaving the room or the next gift.
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _finish();
  }

  @override
  void dispose() {
    _done = true;
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(children: [
            if (!_done && _controller != null)
              Center(
                  child: SizedBox(
                width: size.width,
                height: size.height * .72,
                child: IgnorePointer(child: VapPlayer(_controller!)),
              )),
            Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Skip gift animation',
                  onPressed: _finish,
                  icon: const Icon(Icons.close),
                )),
            Positioned(
                left: 12,
                right: 12,
                bottom: 72,
                child: IgnorePointer(
                  child: Text(
                    '${gift.sender} sent ${gift.giftName} × ${gift.quantity} '
                    'to ${gift.recipient} · ${gift.settledCoins} coins',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xffd6a545), fontWeight: FontWeight.w700),
                  ),
                )),
          ]),
        ));
  }
}

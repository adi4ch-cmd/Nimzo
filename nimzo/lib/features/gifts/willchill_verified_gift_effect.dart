import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Only explicitly matching, server-named coin gifts may use the coin VAP.
/// Price alone is never evidence that gold-coin artwork belongs to the gift.
bool isWillChillGoldCoinGift(String giftName) {
  final name = giftName.toLowerCase().trim();
  return name == 'gold coin' || name == 'gold coins' ||
      name == 'coin rain' || name == 'goldcoin';
}

/// Optional visual-only effect for an already verified, settled room gift.
/// Never initiates transactions or accepts an unverified client gift event.
/// Missing/corrupt source media always falls back to the existing NIMZO
/// celebration without changing gift delivery or the wallet balance.
class WillChillVerifiedGiftEffect extends StatefulWidget {
  const WillChillVerifiedGiftEffect({
    super.key,
    required this.totalCoins,
    required this.giftName,
    required this.sender,
    required this.recipient,
    required this.fallback,
    required this.onFinished,
  });

  final int totalCoins;
  final String giftName;
  final String sender;
  final String recipient;
  final Widget fallback;
  final VoidCallback onFinished;

  @override
  State<WillChillVerifiedGiftEffect> createState() =>
      _WillChillVerifiedGiftEffectState();
}

class _WillChillVerifiedGiftEffectState
    extends State<WillChillVerifiedGiftEffect> {
  VapPlayerController? _controller;
  StreamSubscription<VapEvent>? _subscription;
  Timer? _watchdog;
  bool _ready = false;
  bool _failed = false;
  bool _finished = false;

  String get _path => widget.totalCoins >= 5000000
      ? 'assets/willchill_premium/gifts/voiceroom_goldcoin_explode.mp4'
      : 'assets/willchill_premium/gifts/voiceroom_goldcoin_spray.mp4';

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(_path)) {
        _fail();
        return;
      }
      if (!mounted || _finished) return;
      final player = VapPlayerController.asset(
        _path,
        options: const VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.fitCenter,
          repeatCount: 0,
          mute: true, // Do not compete with live room voice audio.
        ),
      );
      _controller = player;
      _subscription = player.events.listen((event) {
        if (event is VapCompletedEvent) _finish();
        if (event is VapErrorEvent) _fail();
      }, onError: (Object _) => _fail());
      _watchdog = Timer(const Duration(seconds: 15), _fail);
      await player.initialize();
      if (!mounted || _finished || _failed) return;
      setState(() => _ready = true);
      await player.play();
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _finished || _failed) return;
    _watchdog?.cancel();
    setState(() => _failed = true);
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
    unawaited(_subscription?.cancel());
    final player = _controller;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    return Material(
      type: MaterialType.transparency,
      child: Stack(fit: StackFit.expand, children: [
        if (_ready && _controller != null)
          Positioned.fill(
            child: IgnorePointer(child: VapPlayer(_controller!)),
          ),
        if (!_ready)
          const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 24,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xcc1d2927),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${widget.sender} sent ${widget.giftName} to ${widget.recipient}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Locally displays the signed-in member's already-earned SVIP crown once
/// after a confirmed room join. This is NOT a room-wide broadcast or an
/// entitlement grant. Missing native playback never blocks the voice room.
class WillChillOwnSvipEntrance extends StatefulWidget {
  const WillChillOwnSvipEntrance({super.key, required this.svipLevel});
  final int svipLevel;

  @override
  State<WillChillOwnSvipEntrance> createState() =>
      _WillChillOwnSvipEntranceState();
}

class _WillChillOwnSvipEntranceState extends State<WillChillOwnSvipEntrance>
    with WidgetsBindingObserver {
  VapPlayerController? _controller;
  StreamSubscription<VapEvent>? _events;
  Timer? _watchdog;
  bool _ready = false;
  bool _finished = false;

  String get _asset =>
      'assets/willchill_premium/entrances/voiceroom_crown_orb_${widget.svipLevel}.mp4';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_play());
  }

  Future<void> _play() async {
    if (widget.svipLevel < 1 || widget.svipLevel > 8) {
      _finish();
      return;
    }
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(_asset) || !mounted || _finished) {
        _finish();
        return;
      }
      final controller = VapPlayerController.asset(
        _asset,
        options: const VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.fitCenter,
          repeatCount: 0,
          mute: true,
        ),
      );
      _controller = controller;
      _events = controller.events.listen(
        (event) {
          if (event is VapCompletedEvent || event is VapErrorEvent) {
            _finish();
          }
        },
        onError: (Object _) => _finish(),
      );
      _watchdog = Timer(const Duration(seconds: 12), _finish);
      await controller.initialize();
      if (!mounted || _finished) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    _watchdog?.cancel();
    if (_finished) return;
    _finished = true;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _finish();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events?.cancel());
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished || !_ready || _controller == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Stack(children: [
        Positioned.fill(child: VapPlayer(_controller!)),
        Positioned(
          top: 42,
          left: 8,
          right: 8,
          child: SafeArea(
            child: Text('Your SVIP ${widget.svipLevel} entrance',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

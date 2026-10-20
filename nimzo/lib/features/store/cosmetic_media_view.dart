import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

import 'premium_cosmetics.dart';

/// Renders the same pinned original media in the Store and on equipped surfaces.
class CosmeticMediaView extends StatefulWidget {
  const CosmeticMediaView({
    super.key,
    required this.media,
    this.animate = true,
    this.onFinished,
  });
  final CosmeticMedia media;
  final bool animate;
  final VoidCallback? onFinished;
  @override
  State<CosmeticMediaView> createState() => _CosmeticMediaViewState();
}

class _CosmeticMediaViewState extends State<CosmeticMediaView>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _svga;
  VapPlayerController? _vap;
  StreamSubscription<VapEvent>? _events;
  bool _ready = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    if (widget.media.kind == CosmeticMediaKind.svga ||
        (widget.animate && widget.media.kind == CosmeticMediaKind.vap))
      unawaited(_load());
  }

  Future<void> _load() async {
    try {
      if (widget.media.kind == CosmeticMediaKind.svga) {
        final controller = SVGAAnimationController(vsync: this)..muted = true;
        _svga = controller;
        final bytes = await rootBundle.load(widget.media.asset);
        final movie = await SVGAParser.shared.decodeFromBuffer(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        if (!mounted) {
          movie.dispose();
          return;
        }
        controller.videoItem = movie;
        setState(() => _ready = true);
        if (widget.onFinished != null) {
          await controller.forward();
          if (mounted) widget.onFinished?.call();
        } else if (widget.animate) {
          controller.repeat();
        } else {
          controller.value = .5;
        }
      } else {
        final controller = VapPlayerController.asset(
          widget.media.asset,
          options: const VapPlayerOptions(
            viewType: VapViewType.textureView,
            scaleType: VapScaleType.fitCenter,
            repeatCount: 0,
            mute: true,
          ),
        );
        _vap = controller;
        _events = controller.events.listen((event) {
          if (event is VapErrorEvent) _fail();
          if (mounted && event is VapCompletedEvent) widget.onFinished?.call();
        }, onError: (Object _) => _fail());
        await controller.initialize();
        if (!mounted) return;
        setState(() => _ready = true);
        await controller.play();
      }
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (mounted) {
      setState(() => _failed = true);
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    _svga?.dispose();
    _vap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed)
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          semanticLabel: 'Media unavailable',
        ),
      );
    final media = widget.media;
    if (media.kind == CosmeticMediaKind.image ||
        (!widget.animate && media.thumbnail != null)) {
      return Image.asset(
        media.thumbnail != null && !widget.animate
            ? media.thumbnail!
            : media.asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }
    if (!_ready)
      return Center(
        child: Icon(
          media.kind == CosmeticMediaKind.vap
              ? Icons.play_circle_outline
              : Icons.hourglass_empty,
        ),
      );
    if (_svga != null) return SVGAImage(_svga!, fit: BoxFit.contain);
    return VapPlayer(_vap!);
  }
}

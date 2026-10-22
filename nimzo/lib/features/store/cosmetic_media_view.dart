import '../../core/services/renderable_media.dart';
import '../../core/services/verified_media_file.dart';
import '../../core/widgets/published_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

import 'premium_cosmetics.dart';
import '../../core/services/approved_media_bytes.dart';

/// Renders the same pinned original media in the Store and on equipped surfaces.
class CosmeticMediaView extends StatelessWidget {
  const CosmeticMediaView(
      {super.key, required this.media, this.animate = true, this.onFinished});
  final CosmeticMedia media;
  final bool animate;
  final VoidCallback? onFinished;
  @override
  Widget build(BuildContext context) => _CosmeticMediaPlayback(
      key: ValueKey(
          '${media.id}:${media.asset}:${media.kind}:${media.publication?.cacheKey}:$animate'),
      media: media,
      animate: animate,
      onFinished: onFinished);
}

class _CosmeticMediaPlayback extends StatefulWidget {
  const _CosmeticMediaPlayback({
    super.key,
    required this.media,
    this.animate = true,
    this.onFinished,
  });
  final CosmeticMedia media;
  final bool animate;
  final VoidCallback? onFinished;
  @override
  State<_CosmeticMediaPlayback> createState() => _CosmeticMediaViewState();
}

class _CosmeticMediaViewState extends State<_CosmeticMediaPlayback>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _svga;
  VapPlayerController? _vap;
  VerifiedMediaFile? _verifiedFile;
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
        final bytes = ApprovedMediaBytes.isSafeUrl(widget.media.asset)
            ? await ApprovedMediaBytes.fetch(widget.media.asset,
                publication: widget.media.publication)
            : await rootBundle.load(widget.media.asset).then((data) => data
                .buffer
                .asUint8List(data.offsetInBytes, data.lengthInBytes));
        if (widget.media.publication != null)
          await validateRenderableMedia(bytes, widget.media.publication!);
        final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
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
        final options = const VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.fitCenter,
          repeatCount: 0,
          mute: true,
        );
        if (ApprovedMediaBytes.isSafeUrl(widget.media.asset) &&
            widget.media.publication != null) {
          final file = await VerifiedMediaFile.create(
              widget.media.asset, widget.media.publication!);
          if (!mounted) {
            await file.dispose();
            return;
          }
          _verifiedFile = file;
        }
        final controller = _verifiedFile != null
            ? VapPlayerController.file(_verifiedFile!.file, options: options)
            : ApprovedMediaBytes.isSafeUrl(widget.media.asset)
                ? VapPlayerController.networkUrl(Uri.parse(widget.media.asset),
                    options: options)
                : VapPlayerController.asset(widget.media.asset,
                    options: options);
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
    unawaited(_events?.cancel());
    _svga?.dispose();
    final vap = _vap;
    final file = _verifiedFile;
    if (vap != null) {
      unawaited(vap.dispose().whenComplete(() async {
        await file?.dispose();
      }));
    } else {
      unawaited(file?.dispose());
    }
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
      final source = media.thumbnail != null && !widget.animate
          ? media.thumbnail!
          : media.asset;
      return ApprovedMediaBytes.isSafeUrl(source)
          ? PublishedImage(
              url: source,
              publication: source == media.asset
                  ? media.publication
                  : media.thumbnailPublication,
              fit: BoxFit.contain,
              unavailable: const Icon(Icons.broken_image_outlined),
            )
          : Image.asset(
              source,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined),
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

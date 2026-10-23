import '../../core/services/renderable_media.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

import '../../core/services/approved_media_bytes.dart';
import 'membership_catalog.dart';

/// Every remote renderer consumes checksum/size/MIME-verified bytes. Native
/// playback reads a private temporary file, never an unchecked network URL.
class MembershipMediaView extends StatefulWidget {
  const MembershipMediaView(
      {super.key,
      required this.media,
      this.animate = false,
      this.fit = BoxFit.contain,
      this.onReady,
      this.onUnavailable,
      this.onFinished});
  final MembershipMedia media;
  final bool animate;
  final BoxFit fit;
  final VoidCallback? onReady, onUnavailable, onFinished;
  @override
  State<MembershipMediaView> createState() => _MembershipMediaViewState();
}

class _MembershipMediaViewState extends State<MembershipMediaView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Uint8List? _image;
  SVGAAnimationController? _svga;
  VapPlayerController? _vap;
  StreamSubscription<VapEvent>? _events;
  Directory? _directory;
  Timer? _watchdog;
  bool _failed = false, _ready = false, _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final media = widget.media;
    try {
      final publication = ApprovedMediaPublication(
          sha256Hex: media.sha256,
          byteLength: media.bytes,
          codec: media.format,
          mimeType: switch (media.format) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'jpeg' => 'image/jpeg',
            'svga' => 'application/x-svga',
            'vap' => 'video/mp4',
            _ => throw const FormatException('Unsupported membership format'),
          });
      final Uint8List bytes;
      if (media.isBundled) {
        final data = await rootBundle.load(media.url);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        publication.validate(bytes, publication.mimeType);
      } else {
        bytes = await ApprovedMediaBytes.fetch(media.url,
            maxBytes: media.bytes, publication: publication);
      }
      if (!mounted || _finished) return;
      if (media.format == 'svga') {
        await validateRenderableMedia(bytes, publication);
        final controller = SVGAAnimationController(vsync: this)..muted = true;
        _svga = controller;
        final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
        if (!mounted || _finished) {
          movie.dispose();
          return;
        }
        controller.videoItem = movie;
        setState(() => _ready = true);
        widget.onReady?.call();
        if (widget.animate) {
          _watchdog = Timer(const Duration(seconds: 12), _finish);
          await controller.forward();
          if (mounted) _finish();
        } else {
          // Non-entrance SVGAs are decorative heroes with real motion.
          controller.repeat();
        }
      } else if (media.format == 'vap') {
        if (!widget.animate)
          throw const FormatException('Entrance requires playback');
        final directory =
            await Directory.systemTemp.createTemp('nimzo-membership-');
        _directory = directory;
        final file = File('${directory.path}/${media.sha256}.mp4');
        await file.writeAsBytes(bytes, flush: true);
        if (!mounted || _finished) {
          await _removeFile();
          return;
        }
        final controller = VapPlayerController.file(file,
            options: const VapPlayerOptions(
                viewType: VapViewType.textureView,
                scaleType: VapScaleType.fitCenter,
                repeatCount: 0,
                mute: true));
        _vap = controller;
        _events = controller.events.listen((event) {
          if (event is VapCompletedEvent) _finish();
          if (event is VapErrorEvent) _fail();
        }, onError: (Object _) => _fail());
        _watchdog = Timer(const Duration(seconds: 12), _finish);
        await controller.initialize();
        if (!mounted || _finished) return;
        setState(() => _ready = true);
        widget.onReady?.call();
        await controller.play();
      } else {
        // Decode first so a magic-valid but corrupt image cannot enable checkout.
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        codec.dispose();
        if (!mounted || _finished) return;
        setState(() {
          _image = bytes;
          _ready = true;
        });
        widget.onReady?.call();
      }
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
    widget.onUnavailable?.call();
    _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    _svga?.stop();
    if (mounted) {
      setState(() {});
      widget.onFinished?.call();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && widget.animate) _finish();
    if (!widget.animate && _svga != null && _ready && !_failed) {
      if (state == AppLifecycleState.resumed) {
        _svga!.repeat();
      } else {
        _svga!.stop();
      }
    }
  }

  Future<void> _removeFile() async {
    final dir = _directory;
    _directory = null;
    if (dir != null && await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _disposeNative() async {
    await _events?.cancel();
    await _vap?.dispose();
    await _removeFile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _svga?.dispose();
    unawaited(_disposeNative());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed)
      return const Center(
          child: Text('Artwork unavailable',
              style: TextStyle(color: Colors.grey)));
    if (_finished && widget.animate) return const SizedBox.shrink();
    if (!_ready) return const Center(child: CircularProgressIndicator());
    if (_image != null) return Image.memory(_image!, fit: widget.fit);
    if (_svga != null) return SVGAImage(_svga!, fit: widget.fit);
    if (_vap != null) return VapPlayer(_vap!);
    return const SizedBox.shrink();
  }
}

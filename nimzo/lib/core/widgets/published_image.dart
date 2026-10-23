import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/approved_media_bytes.dart';

/// Approved remote images use bounded downloads, verified immutable metadata
/// when supplied, and a bounded decode width instead of an unbounded URL image.
class PublishedImage extends StatefulWidget {
  const PublishedImage(
      {super.key,
      required this.url,
      this.publication,
      this.fit = BoxFit.contain,
      this.unavailable = const Icon(Icons.broken_image_outlined)});
  final String url;
  final ApprovedMediaPublication? publication;
  final BoxFit fit;
  final Widget unavailable;
  @override
  State<PublishedImage> createState() => _PublishedImageState();
}

class _PublishedImageState extends State<PublishedImage> {
  late Future<Uint8List> _bytes;
  void _load() => _bytes = ApprovedMediaBytes.fetch(widget.url,
      publication: widget.publication, maxBytes: 8 * 1024 * 1024);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublishedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.publication?.cacheKey != widget.publication?.cacheKey)
      _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (_, value) => value.hasData
          ? Image.memory(value.data!,
              fit: widget.fit,
              cacheWidth: 1024,
              errorBuilder: (_, __, ___) => widget.unavailable)
          : value.hasError
              ? widget.unavailable
              : const Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))));
}

/// Bounded image layer; a failed background leaves the existing room palette.
class PublishedBackground extends StatelessWidget {
  const PublishedBackground(
      {super.key, required this.url, this.publication, required this.child});
  final String? url;
  final ApprovedMediaPublication? publication;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        if (url != null)
          Positioned.fill(
              child: IgnorePointer(
                  child: PublishedImage(
                      url: url!,
                      publication: publication,
                      fit: BoxFit.cover,
                      unavailable: const SizedBox.shrink()))),
        child,
      ]);
}

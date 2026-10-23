import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_svga/flutter_svga.dart';
import 'approved_media_bytes.dart';

/// Decode proof before a new charge. Native VAP/MP4 additionally requires the
/// publisher's device proof; no local image is represented as native playback.
Future<void> validateRenderableMedia(
    Uint8List bytes, ApprovedMediaPublication publication) async {
  if (publication.codec == 'svga') {
    final sink = _BoundedInflation();
    final decoder = ZLibDecoder()
        .startChunkedConversion(ByteConversionSink.from(sink));
    try {
      for (var offset = 0; offset < bytes.length; offset += 4096) {
        decoder.add(bytes.sublist(offset,
            offset + 4096 > bytes.length ? bytes.length : offset + 4096));
      }
      decoder.close();
    } catch (_) {
      throw const FormatException('Unsupported SVGA compression');
    }
    final movie = MovieEntity.fromBuffer(sink.bytes.takeBytes());
    try {
      final p = movie.params;
      if (!movie.hasParams() ||
          !p.viewBoxWidth.isFinite ||
          !p.viewBoxHeight.isFinite ||
          p.viewBoxWidth <= 0 ||
          p.viewBoxHeight <= 0 ||
          p.viewBoxWidth > 4096 ||
          p.viewBoxHeight > 4096 ||
          p.fps < 1 ||
          p.fps > 60 ||
          p.frames < 1 ||
          p.frames > 3600 ||
          movie.sprites.isEmpty ||
          movie.sprites.length > 256 ||
          movie.images.length > 128 ||
          movie.sprites.any((s) => s.frames.length > 3600)) {
        throw const FormatException('SVGA bounds or frames unsupported');
      }
      var pixels = 0;
      for (final image in movie.images.values) {
        // Audio is decoded by the existing SVGA player; keep image validation
        // separate from embedded MP3 resources (ID3 or MPEG frame header).
        if (image.length >= 3 &&
            ((image[0] == 73 && image[1] == 68 && image[2] == 51) ||
                (image[0] == 255 && image[1] & 224 == 224))) continue;
        pixels += await _decodeImage(Uint8List.fromList(image));
        if (pixels > 32000000)
          throw const FormatException('SVGA decoded image budget exceeded');
      }
    } finally {
      movie.dispose();
    }
  } else if (const {'png', 'jpeg', 'webp'}.contains(publication.codec)) {
    await _decodeImage(bytes);
  }
}

Future<int> _decodeImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final pixels = descriptor.width * descriptor.height;
    if (descriptor.width < 1 ||
        descriptor.height < 1 ||
        descriptor.width > 4096 ||
        descriptor.height > 4096 ||
        pixels > 16000000) {
      throw const FormatException('Decoded image bounds exceeded');
    }
    codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    frame.image.dispose();
    return pixels;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

class _BoundedInflation implements Sink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > 24 * 1024 * 1024) {
      throw const FormatException('SVGA decompressed limit exceeded');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

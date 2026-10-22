import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Immutable publication metadata supplied by the authorized catalog. A checksum
/// proves byte identity, not permission, device playback or wallet entitlement.
class ApprovedMediaPublication {
  const ApprovedMediaPublication({
    required this.sha256Hex,
    required this.byteLength,
    required this.mimeType,
    required this.codec,
  });

  final String sha256Hex;
  final int byteLength;
  final String mimeType;
  final String codec;

  bool get isValid =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256Hex) &&
      byteLength > 0 &&
      byteLength <= ApprovedMediaBytes.defaultLimit &&
      const {
            'image/png': 'png',
            'image/jpeg': 'jpeg',
            'image/webp': 'webp',
            'video/mp4': 'mp4',
            'application/x-svga': 'svga',
          }[mimeType] ==
          (codec == 'vap' ? 'mp4' : codec);

  void validate(Uint8List bytes, String? responseMime) {
    if (!isValid ||
        bytes.length != byteLength ||
        sha256.convert(bytes).toString() != sha256Hex ||
        responseMime?.toLowerCase() != mimeType ||
        !_matchesMagic(bytes)) {
      throw const FormatException('Published media integrity mismatch');
    }
  }

  bool _matchesMagic(Uint8List b) {
    bool starts(List<int> signature) =>
        b.length >= signature.length &&
        List.generate(signature.length, (i) => b[i] == signature[i])
            .every((value) => value);
    switch (codec) {
      case 'png':
        return starts([137, 80, 78, 71, 13, 10, 26, 10]);
      case 'jpeg':
        return starts([255, 216, 255]);
      case 'webp':
        return starts([82, 73, 70, 70]) &&
            b.length >= 12 &&
            String.fromCharCodes(b.sublist(8, 12)) == 'WEBP';
      case 'vap':
        return _validVapContainer(b);
      case 'mp4':
        return b.length >= 12 &&
            String.fromCharCodes(b.sublist(4, 8)) == 'ftyp';
      // SVGA 2.x is zlib compressed; a valid header is only a cheap preflight.
      // The shipped decoder must still validate/decompress its protobuf safely.
      case 'svga':
        return b.length >= 2 &&
            (b[0] & 15) == 8 &&
            b[0] >> 4 <= 7 &&
            (b[0] * 256 + b[1]) % 31 == 0;
      default:
        return false;
    }
  }

  // Parse actual top-level ISO BMFF atoms, never search arbitrary payload bytes
  // for "vapc" (ordinary MP4 mdat bytes may contain that text by coincidence).
  bool _validVapContainer(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    var foundConfig = false;
    var foundMovie = false;
    var foundMedia = false;
    try {
      while (offset < bytes.length) {
        if (bytes.length - offset < 8) return false;
        var size = data.getUint32(offset);
        final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
        var header = 8;
        if (size == 1) {
          if (bytes.length - offset < 16) return false;
          size = data.getUint64(offset + 8);
          header = 16;
        } else if (size == 0) {
          size = bytes.length - offset;
        }
        if (size < header || size > bytes.length - offset) return false;
        if (offset == 0 && (type != 'ftyp' || size < header + 8)) return false;
        if (type == 'moov') foundMovie = true;
        if (type == 'mdat' && size > header) foundMedia = true;
        if (type == 'vapc') {
          if (foundConfig || size - header > 65536) return false;
          final config = jsonDecode(
              utf8.decode(bytes.sublist(offset + header, offset + size)));
          if (config is! Map || !_validVapInfo(config['info'])) return false;
          foundConfig = true;
        }
        offset += size;
      }
      return foundConfig && foundMovie && foundMedia;
    } on Object {
      return false;
    }
  }

  bool _validVapInfo(dynamic info) {
    if (info is! Map) return false;
    bool positiveInt(dynamic value, int max) =>
        value is int && value > 0 && value <= max;
    if (info['v'] != 2 ||
        info['isVapx'] != 0 ||
        !positiveInt(info['f'], 100000) ||
        !positiveInt(info['fps'], 120) ||
        !positiveInt(info['w'], 8192) ||
        !positiveInt(info['h'], 8192) ||
        !positiveInt(info['videoW'], 8192) ||
        !positiveInt(info['videoH'], 8192)) {
      return false;
    }
    for (final key in ['rgbFrame', 'aFrame']) {
      final rect = info[key];
      if (rect is! List || rect.length != 4 || rect.any((v) => v is! int))
        return false;
      if (rect[0] < 0 ||
          rect[1] < 0 ||
          rect[2] <= 0 ||
          rect[3] <= 0 ||
          rect[0] + rect[2] > info['videoW'] ||
          rect[1] + rect[3] > info['videoH']) return false;
    }
    return true;
  }

  String get cacheKey => '$sha256Hex:$byteLength:$mimeType:$codec';
}

/// Bounded HTTPS downloads. Legacy callers may omit publication metadata;
/// those bytes are never cached, and are not represented as verified media.
abstract final class ApprovedMediaBytes {
  static const int defaultLimit = 32 * 1024 * 1024;
  static const int cacheLimit = 24 * 1024 * 1024;
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List>> _inFlight = {};
  static int _generation = 0;

  static bool isSafeUrl(String? value) {
    if (value == null ||
        value.length > 2048 ||
        value.trim() != value ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(value)) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        (!uri.hasPort || uri.port == 443);
  }

  /// Account changes revoke cache access, including pending old-account loads.
  static void clearCache() {
    _generation++;
    _cache.clear();
    _inFlight.clear();
  }

  static Future<Uint8List> fetch(
    String url, {
    int maxBytes = defaultLimit,
    ApprovedMediaPublication? publication,
  }) async {
    if (!isSafeUrl(url) ||
        maxBytes <= 0 ||
        maxBytes > defaultLimit ||
        (publication != null &&
            (!publication.isValid ||
                publication.byteLength > maxBytes ||
                !Uri.parse(url).path.contains(publication.sha256Hex)))) {
      throw const FormatException('Unapproved media URL or size');
    }
    final key = '$url:${publication?.cacheKey}:$maxBytes';
    final cached = _cache[key];
    if (cached != null) return Uint8List.fromList(cached);
    final generation = _generation;
    var request = _inFlight[key];
    if (request == null) {
      request = _load(url, maxBytes: maxBytes, publication: publication);
      _inFlight[key] = request;
      final current = request;
      unawaited(current.whenComplete(() {
        if (identical(_inFlight[key], current)) _inFlight.remove(key);
      }).then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    }
    final data = await request;
    if (generation != _generation) {
      throw const FormatException('Media request belongs to previous session');
    }
    if (publication != null &&
        data.length <= cacheLimit &&
        !_cache.containsKey(key)) {
      var total = _cache.values.fold<int>(0, (n, bytes) => n + bytes.length);
      while (_cache.isNotEmpty && total + data.length > cacheLimit) {
        total -= _cache.remove(_cache.keys.first)!.length;
      }
      _cache[key] = Uint8List.fromList(data);
    }
    return Uint8List.fromList(data);
  }

  static Future<Uint8List> _load(
    String url, {
    required int maxBytes,
    required ApprovedMediaPublication? publication,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      // Whole operation timeout also bounds slow trickle streams. Per-chunk
      // timeouts alone allow an attacker to keep a decoder download alive forever.
      return await (() async {
        final request = await client.getUrl(Uri.parse(url));
        request.followRedirects = false;
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok ||
            response.contentLength > maxBytes ||
            (publication != null &&
                response.contentLength >= 0 &&
                response.contentLength != publication.byteLength)) {
          throw const FormatException('Media unavailable or oversized');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk
            in response.timeout(const Duration(seconds: 12))) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const FormatException('Media exceeded download limit');
          }
          bytes.add(chunk);
        }
        final data = bytes.takeBytes();
        if (data.isEmpty) throw const FormatException('Empty media');
        publication?.validate(data, response.headers.contentType?.mimeType);
        return data;
      })()
          .timeout(const Duration(seconds: 30));
    } finally {
      client.close(force: true);
    }
  }
}

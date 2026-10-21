import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Bound downloads of server-approved HTTPS SVGA files. Assets must already be
/// authorized by the catalog; this utility never checks wallet entitlements.
abstract final class ApprovedMediaBytes {
  static const int defaultLimit = 32 * 1024 * 1024;
  static const int cacheLimit = 24 * 1024 * 1024;
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List>> _inFlight = {};

  static bool isSafeUrl(String? value) {
    if (value == null || value.length > 2048) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static Future<Uint8List> fetch(
    String url, {
    int maxBytes = defaultLimit,
  }) {
    if (!isSafeUrl(url) || maxBytes <= 0 || maxBytes > defaultLimit) {
      throw const FormatException('Unapproved media URL or size');
    }
    final cached = _cache[url];
    if (cached != null && cached.length <= maxBytes) {
      return Future.value(cached);
    }
    final pending = _inFlight[url];
    if (pending != null) return pending.then((bytes) {
      if (bytes.length > maxBytes) {
        throw const FormatException('Media too large for this surface');
      }
      return bytes;
    });
    final request = _load(url, maxBytes: maxBytes);
    _inFlight[url] = request;
    unawaited(request.whenComplete(() => _inFlight.remove(url))
        .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    return request;
  }

  static Future<Uint8List> _load(String url, {required int maxBytes}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      final response = await request.close()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > maxBytes) {
        throw const FormatException('Media unavailable or oversized');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Media exceeded download limit');
        }
        bytes.add(chunk);
      }
      final data = bytes.takeBytes();
      if (data.isEmpty) throw const FormatException('Empty media');
      if (data.length <= cacheLimit) {
        var total = _cache.values.fold<int>(0, (n, bytes) => n + bytes.length);
        while (_cache.isNotEmpty && total + data.length > cacheLimit) {
          final oldest = _cache.keys.first;
          total -= _cache.remove(oldest)!.length;
        }
        _cache[url] = data;
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }
}

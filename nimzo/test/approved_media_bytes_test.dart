import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';

class _Headers extends Fake implements HttpHeaders {
  _Headers(this.mime);
  final String mime;
  @override
  ContentType? get contentType => ContentType.parse(mime);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.chunks,
      {this.declaredLength = -1, this.status = 200, this.mime = 'image/png'});
  final List<List<int>> chunks;
  final int declaredLength;
  final int status;
  final String mime;
  @override
  int get statusCode => status;
  @override
  int get contentLength => declaredLength;
  @override
  HttpHeaders get headers => _Headers(mime);
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable(chunks).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  set followRedirects(bool value) {
    expect(value, isFalse);
  }

  @override
  Future<HttpClientResponse> close() async => response;
}

class _Client extends Fake implements HttpClient {
  _Client(this.response);
  _Response response;
  int requests = 0;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    return _Request(response);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
  final url = 'https://cdn.example/${sha256.convert(png)}.png';
  ApprovedMediaPublication publication(Uint8List bytes) =>
      ApprovedMediaPublication(
          sha256Hex: sha256.convert(bytes).toString(),
          byteLength: bytes.length,
          mimeType: 'image/png',
          codec: 'png');
  setUp(ApprovedMediaBytes.clearCache);

  test(
      'VAP requires an actual bounded vapc atom and complete packed frame config',
      () {
    List<int> atom(String type, List<int> payload) {
      final header = ByteData(8)..setUint32(0, payload.length + 8);
      return [
        ...header.buffer.asUint8List().sublist(0, 4),
        ...ascii.encode(type),
        ...payload
      ];
    }

    final info = <String, dynamic>{
      'v': 2,
      'isVapx': 0,
      'f': 36,
      'fps': 24,
      'w': 750,
      'h': 750,
      'videoW': 1136,
      'videoH': 752,
      'aFrame': [754, 0, 375, 375],
      'rgbFrame': [0, 0, 750, 750]
    };
    Uint8List video(Map<String, dynamic>? config, {bool fake = false}) =>
        Uint8List.fromList([
          ...atom('ftyp', List.filled(8, 0)),
          ...atom('moov', []),
          if (config != null)
            ...atom('vapc', utf8.encode(jsonEncode({'info': config}))),
          ...atom('mdat', fake ? utf8.encode('vapc') : [1]),
        ]);
    void validate(Uint8List bytes) => ApprovedMediaPublication(
            sha256Hex: sha256.convert(bytes).toString(),
            byteLength: bytes.length,
            mimeType: 'video/mp4',
            codec: 'vap')
        .validate(bytes, 'video/mp4');
    validate(video(info));
    expect(() => validate(video(null, fake: true)), throwsFormatException);
    expect(
        () => validate(video({
              ...info,
              'aFrame': [1100, 0, 375, 375]
            })),
        throwsFormatException);
    expect(
        () => validate(video({...info, 'isVapx': 1})), throwsFormatException);
    expect(() => validate(video({...info, 'fps': 0})), throwsFormatException);
    final truncated = video(info)..[3] = 255;
    expect(() => validate(truncated), throwsFormatException);
  });

  test(
      'approved URL rejects credentials, whitespace, fragments and alternate ports',
      () {
    for (final unsafe in [
      'http://cdn.example/x',
      'https://u:p@cdn.example/x',
      'https://cdn.example/x#fragment',
      'https://cdn.example:8443/x',
      ' https://cdn.example/x',
      'https://cdn.example/x\n'
    ]) {
      expect(ApprovedMediaBytes.isSafeUrl(unsafe), isFalse, reason: unsafe);
    }
  });

  test('digest size MIME and magic all independently fail closed', () {
    final p = publication(png);
    p.validate(png, 'image/png');
    expect(() => p.validate(png, 'text/html'), throwsFormatException);
    expect(() => p.validate(Uint8List.fromList([...png, 1]), 'image/png'),
        throwsFormatException);
    final changed = Uint8List.fromList(png)..[8] = 2;
    expect(() => p.validate(changed, 'image/png'), throwsFormatException);
    final wrongMagic = Uint8List.fromList(List.filled(png.length, 42));
    expect(() => publication(wrongMagic).validate(wrongMagic, 'image/png'),
        throwsFormatException);
  });

  test('verified HTTP response cache is isolated from caller mutation',
      () async {
    final client = _Client(_Response([png], declaredLength: png.length));
    await HttpOverrides.runZoned(() async {
      final first =
          await ApprovedMediaBytes.fetch(url, publication: publication(png));
      first[0] = 0;
      final second =
          await ApprovedMediaBytes.fetch(url, publication: publication(png));
      expect(second, png);
      expect(client.requests, 1);
      ApprovedMediaBytes.clearCache();
      await ApprovedMediaBytes.fetch(url, publication: publication(png));
      expect(client.requests, 2);
    }, createHttpClient: (_) => client);
  });

  test('same URL updated publication never returns stale cached bytes',
      () async {
    final client = _Client(_Response([png], declaredLength: png.length));
    await HttpOverrides.runZoned(() async {
      await ApprovedMediaBytes.fetch(url, publication: publication(png));
      final next = Uint8List.fromList(png)..[8] = 7;
      client.response = _Response([next], declaredLength: next.length);
      await expectLater(
          ApprovedMediaBytes.fetch(url, publication: publication(next)),
          throwsFormatException);
      expect(
          await ApprovedMediaBytes.fetch(
              'https://cdn.example/${sha256.convert(next)}.png',
              publication: publication(next)),
          next);
      expect(client.requests, 2);
    }, createHttpClient: (_) => client);
  });

  test('HTTP redirect MIME mismatch and chunked overflow reject before caching',
      () async {
    final client = _Client(_Response([png], status: 302));
    await HttpOverrides.runZoned(() async {
      await expectLater(
          ApprovedMediaBytes.fetch(url, publication: publication(png)),
          throwsFormatException);
      client.response = _Response([png], mime: 'text/html');
      await expectLater(
          ApprovedMediaBytes.fetch(url, publication: publication(png)),
          throwsFormatException);
      client.response = _Response([png, png]);
      await expectLater(ApprovedMediaBytes.fetch(url, maxBytes: png.length),
          throwsFormatException);
    }, createHttpClient: (_) => client);
  });

  test('legacy unverified responses never populate verified cache', () async {
    final client = _Client(_Response([png]));
    await HttpOverrides.runZoned(() async {
      await ApprovedMediaBytes.fetch(url);
      await ApprovedMediaBytes.fetch(url);
      expect(client.requests, 2);
    }, createHttpClient: (_) => client);
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Serves nonpersonal bundled JPEG fixtures through the real NetworkImage path.
class FixtureImageHttpClient implements HttpClient {
  FixtureImageHttpClient(this.fixtures);
  final Map<String, Uint8List> fixtures;
  final requested = <Uri>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested.add(url);
    final bytes = fixtures[url.pathSegments.last];
    if (bytes == null) throw StateError('Unexpected image request: $url');
    return _Request(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

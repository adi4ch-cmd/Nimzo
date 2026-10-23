import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/core/services/renderable_media.dart';

ApprovedMediaPublication publication(Uint8List b, String kind) =>
    ApprovedMediaPublication(
        sha256Hex: sha256.convert(b).toString(),
        byteLength: b.length,
        codec: kind,
        mimeType: kind == 'png' ? 'image/png' : 'application/x-svga');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real shipped PNG and complete SVGA resources decode successfully',
      () async {
    for (final entry in {
      'assets/premium_store/danglive/chatroom-bg.png': 'png',
      'assets/premium_store/danglive/agency-leader.svga': 'svga'
    }.entries) {
      final data = await rootBundle.load(entry.key);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await validateRenderableMedia(bytes, publication(bytes, entry.value));
    }
  });
  test('header-valid but corrupt PNG fails actual decoder', () async {
    final b = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
    await expectLater(
        validateRenderableMedia(b, publication(b, 'png')), throwsA(anything));
  });
  test('SVGA decompressed budget and invalid protobuf fail before render',
      () async {
    for (final raw in [
      Uint8List(25 * 1024 * 1024),
      Uint8List.fromList([1, 2, 3, 4])
    ]) {
      final b = Uint8List.fromList(ZLibEncoder().convert(raw));
      await expectLater(validateRenderableMedia(b, publication(b, 'svga')),
          throwsA(anything));
    }
  });
}

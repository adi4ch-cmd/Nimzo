import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/core/services/renderable_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every imported Drive item passes actual purchase decoder limits',
      () async {
    final manifest = jsonDecode(
            await rootBundle.loadString('assets/drive_catalog/manifest.json'))
        as Map;
    for (final item in (manifest['items'] as List).cast<Map>()) {
      final data = await rootBundle.load(item['asset'] as String);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      debugPrint('PREFLIGHT ${item['name']}');
      await validateRenderableMedia(
          bytes,
          ApprovedMediaPublication(
              sha256Hex: item['sha256'] as String,
              byteLength: item['bytes'] as int,
              mimeType: 'application/x-svga',
              codec: 'svga'));
    }
  });
}

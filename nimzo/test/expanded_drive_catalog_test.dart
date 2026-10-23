import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/core/services/renderable_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'expanded catalog has at least20 new genuine animated gifts and28 Store items passing actual purchase preflight',
      () async {
    final manifest = jsonDecode(await rootBundle
        .loadString('assets/drive_catalog_expanded/manifest.json')) as Map;
    final items = (manifest['items'] as List).cast<Map>();
    expect(items.where((r) => r['category'] == 'gift').length,
        greaterThanOrEqualTo(20));
    expect(items.where((r) => r['category'] != 'gift').length,
        greaterThanOrEqualTo(28));
    final seen = <String>{};
    for (final item in items) {
      expect(seen.add(item['sha256'] as String), isTrue);
      final data = await rootBundle.load(item['asset'] as String);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await validateRenderableMedia(
          bytes,
          ApprovedMediaPublication(
              sha256Hex: item['sha256'] as String,
              byteLength: item['bytes'] as int,
              mimeType: item['mime_type'] as String,
              codec: item['codec'] as String));
      if (item['category'] == 'gift') expect(item['media_kind'], 'svga');
    }
  });
}

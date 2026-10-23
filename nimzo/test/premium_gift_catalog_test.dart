import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/core/services/renderable_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'premium shortlist reports missing gifts and keeps at most two per type',
      () async {
    final m = jsonDecode(await rootBundle
        .loadString('assets/drive_catalog_premium/manifest.json'));
    final items = (m['items'] as List).cast<Map>();
    expect(m['requested_count'], 20);
    expect(m['selected_count'], 7);
    expect(m['remaining_count'], 13);
    expect(items.length, m['selected_count']);
    expect(items.length + (m['remaining_count'] as int), m['requested_count']);
    expect(items.where((r) => r['coin_price'] == 500000).length, 4);
    expect(items.where((r) => r['coin_price'] == 1000000).length, 3);
    final families = <String, int>{};
    for (final item in items) {
      expect(item['family'], isA<String>(),
          reason: 'Every effect needs a reviewed semantic type');
      final family = item['family'] as String;
      expect(family, matches(RegExp(r'^[a-z]+(?:_[a-z]+)*$')));
      families.update(family, (count) => count + 1, ifAbsent: () => 1);
    }
    expect(families.length, 5);
    for (final family in families.entries) {
      expect(family.value, lessThanOrEqualTo(2), reason: family.key);
    }
    final old = <String>{};
    for (final asset in [
      'assets/drive_catalog/manifest.json',
      'assets/drive_catalog_expanded/manifest.json'
    ]) {
      final data = jsonDecode(await rootBundle.loadString(asset));
      old.addAll((data['items'] as List).map((r) => r['sha256'] as String));
    }
    for (final item in items) {
      expect(old.add(item['sha256'] as String), isTrue,
          reason: 'New originals must not repeat current catalog');
      final raw = await rootBundle.load(item['asset']);
      final bytes =
          raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
      final publication = ApprovedMediaPublication(
          sha256Hex: item['sha256'],
          byteLength: item['bytes'],
          mimeType: item['mime_type'],
          codec: item['codec']);
      expect(item['media_kind'], isIn(['vap', 'svga']));
      publication.validate(bytes, item['mime_type']);
      await validateRenderableMedia(bytes, publication);
      if (item['media_kind'] == 'vap') {
        expect(item['vap_config']['info']['isVapx'], 0);
      }
      expect(item['duration_ms'], inInclusiveRange(1000, 30000));
    }
  });
}

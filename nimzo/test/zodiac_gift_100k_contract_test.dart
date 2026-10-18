import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/zodiac_gifts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Libra and Aries have distinct stable IDs and intended 100K price', () {
    expect(libraGiftId, '1178a55b-ebed-59a6-9c6a-efb24893b59b');
    expect(ariesGiftId, '1245657f-3156-5724-a601-e2f5c5fd2e35');
    expect(libraGiftId, isNot(ariesGiftId));
    expect(zodiacGiftPriceCoins, 100000);
    expect(zodiacVapGiftIds, containsAll([libraGiftId, ariesGiftId]));
    expect(zodiacVapGiftIds, hasLength(2));
  });

  test('Libra and Aries icon assets are independently bundled', () async {
    for (final entry in <String, String>{
      libraGiftIconAsset: 'LIBRA',
      ariesGiftIconAsset: 'ARIES',
    }.entries) {
      final bytes = await rootBundle.load(entry.key);
      final svg = String.fromCharCodes(bytes.buffer.asUint8List());
      expect(svg, contains('<svg'), reason: entry.key);
      expect(svg, contains(entry.value), reason: entry.key);
      expect(svg.length, greaterThan(600), reason: entry.key);
    }
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/hall_of_fame_gift.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Hall of Fame uses the expected stable ID and 500K server price', () {
    expect(hallOfFameGiftId, '53f6278f-1770-5be9-ae07-329c34f36c47');
    expect(hallOfFameGiftName, 'Hall of Fame');
    expect(hallOfFameGiftPriceCoins, 500000);
    expect(hallOfFameIconAsset, 'assets/gifts/hall_of_fame.svg');
  });

  test('Hall of Fame original icon is bundled for the catalog', () async {
    final bytes = await rootBundle.load(hallOfFameIconAsset);
    final svg = String.fromCharCodes(bytes.buffer.asUint8List());
    expect(svg, contains('<svg'));
    expect(svg, contains('HALL OF FAME'));
    expect(svg.length, greaterThan(800));
  });
}

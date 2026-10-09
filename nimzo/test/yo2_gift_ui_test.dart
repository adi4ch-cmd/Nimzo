import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/yo2_gift_ui.dart';

void main() {
  test('Gift categories never invent Yo2-only catalog records', () {
    final categories = nimzoGiftCategories([
      'classic',
      'premium',
      'vip',
      'svip',
      'Dragon',
      'CLASSIC',
    ]);
    expect(categories, ['All', 'classic', 'premium', 'vip', 'svip']);
  });

  test(
    'All preserves the catalog, individual tabs match case-insensitively',
    () {
      expect(giftMatchesCategory('premium', 'PREMIUM'), isTrue);
      expect(giftMatchesCategory('classic', 'premium'), isFalse);
      expect(giftMatchesCategory('Dragon', 'All'), isTrue);
    },
  );
}

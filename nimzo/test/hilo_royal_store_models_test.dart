import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_repository.dart';

void main() {
  test('store catalog parses authoritative server prices', () {
    final item = RoyalStoreItem.fromJson({
      'coin_price': 25000,
      'profile_collectibles': {
        'id': 'item1',
        'name': 'Royal Crest II',
        'image_path': 'assets/hilo/store/royal_2.webp',
        'description': 'Permanent',
      },
    });
    expect(item.price, 25000);
    expect(item.image, 'assets/hilo/store/royal_2.webp');
  });
  test('bag reads authoritative equipment state', () {
    final item = RoyalBagItem.fromJson({
      'equipped': true,
      'expires_at': null,
      'profile_collectibles': {
        'id': 'item1',
        'name': 'Royal Crest I',
        'image_path': 'assets/hilo/store/royal_1.webp',
      },
    });
    expect(item.equipped, isTrue);
    expect(item.expiry, isNull);
  });
}

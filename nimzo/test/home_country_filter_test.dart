import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/home/home_screen.dart';

void main() {
  test('country filter accepts ISO code and existing full country name', () {
    expect(roomCountryMatches('PK', 'PK', 'Pakistan'), isTrue);
    expect(roomCountryMatches(' Pakistan ', 'PK', 'Pakistan'), isTrue);
    expect(roomCountryMatches('SA', 'PK', 'Pakistan'), isFalse);
    expect(roomCountryMatches('Saudi Arabia', 'PK', 'Pakistan'), isFalse);
    expect(roomCountryMatches(null, 'PK', 'Pakistan'), isFalse);
    expect(roomCountryMatches(null, null, 'All'), isTrue);
  });
}

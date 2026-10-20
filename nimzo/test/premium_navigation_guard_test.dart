import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/app/feature_availability.dart';

void main() {
  test('VIP and SVIP routes are reachable after activation', () {
    expect(isComingSoonLocation('/vip'), isFalse);
    expect(isComingSoonLocation('/svip'), isFalse);
    expect(isComingSoonLocation('/vip/'), isFalse);
  });
}

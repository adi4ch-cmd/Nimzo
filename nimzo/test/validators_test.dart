import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/utils/validators.dart';

void main() {
  test('email', () {
    expect(Validators.email('a@b.co'), isNull);
    expect(Validators.email('nope'), isNotNull);
  });
  test('username', () {
    expect(Validators.username('ab'), isNotNull);
    expect(Validators.username('nimzo_1'), isNull);
  });
}

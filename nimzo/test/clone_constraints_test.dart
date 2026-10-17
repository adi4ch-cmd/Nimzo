import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/constants/app_constants.dart';

void main() {
  test('NIMZO audio rooms retain exactly ten microphones', () {
    expect(AppConstants.micSeatCount, 10,
      reason: 'The user requires ten seats even when reference shows twelve.');
  });
  test('NIMZO OAuth callback remains bound to our own package', () {
    expect(AppConstants.oauthRedirect, 'io.nimzo.app://login-callback');
  });
}

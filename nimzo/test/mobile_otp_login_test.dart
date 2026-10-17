import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/app/auth_redirect.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';
import 'package:nimzo/features/auth/presentation/mobile_otp_login_screen.dart';

void main() {
  test('SMS phone numbers must use complete E.164 country codes', () {
    expect(validE164Phone('+966512345678'), isTrue);
    expect(validE164Phone('+923001234567'), isTrue);
    expect(validE164Phone('00966512345678'), isFalse);
    expect(validE164Phone('0512345678'), isFalse);
    expect(validE164Phone('+0123456789'), isFalse);
    expect(validE164Phone('+966 512345678'), isFalse);
    expect(validE164Phone('+966512345678999999'), isFalse);
  });

  test('Unauthenticated users can open mobile verification without loops', () {
    expect(authRedirect(
      location: '/phone-login',
      user: null, loading: false, recovering: false), isNull);
  });

  test('Verified phone-only accounts are not redirected to email OTP page', () {
    final user = AuthUser(
      id: 'phone-user',
      email: null,
      emailVerified: true,
    );
    expect(authRedirect(
      location: '/phone-login',
      user: user,
      loading: false,
      recovering: false,
      profileReady: true), '/home');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/app/auth_redirect.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';

void main() {
  test('verified new account cannot bypass required profile setup', () {
    expect(
        authRedirect(
            location: '/home',
            user: const AuthUser(id: 'new', emailVerified: true),
            loading: false,
            recovering: false,
            profileReady: false),
        '/profile-setup');
  });
  test('password recovery stays first even when profile is incomplete', () {
    expect(
        authRedirect(
            location: '/home',
            user: const AuthUser(id: 'new', emailVerified: true),
            loading: false,
            recovering: true,
            profileReady: false),
        '/update-password');
  });
}

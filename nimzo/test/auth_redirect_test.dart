import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/app/auth_redirect.dart';
import 'package:nimzo/app/routes.dart';
import 'package:nimzo/features/auth/domain/auth_user.dart';

void main() {
  const user = AuthUser(
    id: 'test',
    email: 'test@example.com',
    emailVerified: true,
  );
  test('password recovery takes precedence over a valid signed-in session', () {
    expect(
      authRedirect(
        location: Routes.home,
        user: user,
        loading: false,
        recovering: true,
      ),
      Routes.updatePassword,
    );
  });
  test('recovery form stays reachable while recovery is active', () {
    expect(
      authRedirect(
        location: Routes.updatePassword,
        user: user,
        loading: false,
        recovering: true,
      ),
      isNull,
    );
  });
  test('signed-out users cannot reach private routes', () {
    expect(
      authRedirect(
        location: '/room/123',
        user: null,
        loading: false,
        recovering: false,
      ),
      Routes.login,
    );
  });
  test('verified OAuth user exits login without rebuilding navigation', () {
    expect(
      authRedirect(
        location: Routes.login,
        user: user,
        loading: false,
        recovering: false,
      ),
      Routes.home,
    );
  });
  test('loading auth does not expose a private screen', () {
    expect(
      authRedirect(
        location: Routes.home,
        user: null,
        loading: true,
        recovering: false,
      ),
      Routes.splash,
    );
  });
}

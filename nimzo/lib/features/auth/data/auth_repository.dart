import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/errors/error_handler.dart';
import '../domain/auth_user.dart';
import 'auth_service.dart';

class AuthRepository {
  final AuthService _s;
  AuthRepository(this._s);

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(
          id: u.id,
          email: u.email,
          emailVerified: u.emailConfirmedAt != null,
        );

  Stream<AuthUser?> watch() => _s.changes.map((e) => _map(e.session?.user));
  AuthUser? getCurrentUser() => _map(_s.currentUser);

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> signInWithGoogle() =>
      _guard(() => _s.oauth(OAuthProvider.google));
  Future<void> signInWithFacebook() =>
      _guard(() => _s.oauth(OAuthProvider.facebook));
  Future<void> signInWithEmail(String e, String p) =>
      _guard(() => _s.signIn(e, p));
  Future<void> signUpWithEmail(String e, String p) =>
      _guard(() => _s.signUp(e, p));
  Future<void> signOut() => _guard(_s.signOut);
  Future<void> resetPassword(String e) => _guard(() => _s.resetPassword(e));

  Future<bool> verifyEmail({String? resendTo}) => _guard(() async {
    if (resendTo != null) await _s.resendVerification(resendTo);
    final r = await _s.refreshUser();
    return r.user?.emailConfirmedAt != null;
  });
}

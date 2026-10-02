import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';

/// Thin wrapper over Supabase Auth. OAuth callbacks are handled by
/// supabase_flutter's native deep-link/PKCE handling; the app must not
/// manually exchange the callback code a second time.
class AuthService {
  final GoTrueClient _auth;
  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get changes => _auth.onAuthStateChange;

  Future<void> oauth(OAuthProvider provider) async {
    final response = await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : AppConstants.oauthRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!response) {
      throw const AuthException('Unable to start OAuth sign-in.');
    }
  }

  Future<AuthResponse> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(String email, String password) => _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConstants.oauthRedirect,
      );

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) =>
      _auth.resetPasswordForEmail(email);

  Future<void> resendVerification(String email) =>
      _auth.resend(type: OtpType.signup, email: email);

  Future<UserResponse> refreshUser() => _auth.getUser();
}

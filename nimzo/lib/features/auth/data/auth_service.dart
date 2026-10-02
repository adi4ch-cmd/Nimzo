import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';

class AuthService {
  final GoTrueClient _auth;
  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get changes => _auth.onAuthStateChange;

  Future<void> oauth(OAuthProvider provider) async {
    final response = await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : AppConstants.oauthRedirect,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!response) throw const AuthException('Unable to start OAuth sign-in.');
  }

  Future<AuthResponse> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(String email, String password) => _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConstants.oauthRedirect,
      );

  Future<void> signOut() => _auth.signOut();
  Future<void> resetPassword(String email) => _auth.resetPasswordForEmail(email);
  Future<void> resendVerification(String email) =>
      _auth.resend(type: OtpType.signup, email: email);
  Future<UserResponse> refreshUser() => _auth.getUser();
}

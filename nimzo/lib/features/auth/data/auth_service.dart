import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';

/// Thin wrapper over Supabase Auth. No business logic.
class AuthService {
  final GoTrueClient _auth;
  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get changes => _auth.onAuthStateChange;

  Future<void> oauth(OAuthProvider p) =>
      _auth.signInWithOAuth(p, redirectTo: AppConstants.oauthRedirect);

  Future<AuthResponse> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(String email, String password) => _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConstants.oauthRedirect);

  Future<void> signOut() => _auth.signOut();
  Future<void> resetPassword(String email) =>
      _auth.resetPasswordForEmail(email);
  Future<void> resendVerification(String email) =>
      _auth.resend(type: OtpType.signup, email: email);
  Future<UserResponse> refreshUser() => _auth.getUser();
}

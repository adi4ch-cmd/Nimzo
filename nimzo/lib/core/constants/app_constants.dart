class AppConstants {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const oauthRedirect = 'io.nimzo.app://login-callback';
  static const micSeatCount = 10;
}

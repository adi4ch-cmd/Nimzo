class AppConstants {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kvqvlpozqokwarovwmwv.supabase.co',
  );
  // Supabase publishable/anon keys are safe for client apps. Keep this fallback
  // so release APKs still initialize Supabase when CI dart-defines are missing.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_b7z60bWuJEy3l2DcvTbI_Q_YojrHzb8',
  );
  static const oauthRedirect = 'io.nimzo.app://login-callback';
  static const micSeatCount = 10;
}

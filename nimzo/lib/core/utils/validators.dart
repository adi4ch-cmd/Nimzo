class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _username = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String? email(String? v) =>
      (v == null || !_email.hasMatch(v.trim())) ? 'Enter a valid email' : null;

  static String? password(String? v) =>
      (v == null || v.length < 8) ? 'Use at least 8 characters' : null;

  static String? username(String? v) => (v == null || !_username.hasMatch(v))
      ? '3–20 letters, numbers or underscores'
      : null;
}

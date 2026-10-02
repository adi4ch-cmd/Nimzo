class AuthUser {
  final String id;
  final String? email;
  final bool emailVerified;
  const AuthUser({required this.id, this.email, required this.emailVerified});
}

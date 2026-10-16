import '../features/auth/domain/auth_user.dart';
import 'routes.dart';

String? authRedirect({
  required String location,
  required AuthUser? user,
  required bool loading,
  required bool recovering,
  bool profileReady = true,
}) {
  if (loading) return location == Routes.splash ? null : Routes.splash;
  if (recovering && user != null)
    return location == Routes.updatePassword ? null : Routes.updatePassword;
  const public = {
    Routes.onboarding,
    Routes.login,
    Routes.register,
    Routes.forgot,
  };
  if (user == null) {
    if (location == Routes.splash) return Routes.onboarding;
    return public.contains(location) ? null : Routes.login;
  }
  if (!user.emailVerified)
    return location == Routes.verify ? null : Routes.verify;
  if (!profileReady)
    return location == Routes.profileSetup ? null : Routes.profileSetup;
  if (location == Routes.splash ||
      public.contains(location) ||
      location == Routes.verify ||
      location == Routes.updatePassword) return Routes.home;
  return null;
}

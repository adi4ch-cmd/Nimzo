class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const updatePassword = '/update-password';
  static const verify = '/verify';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const games = '/games';
  static const moments = '/moments';
  static const messages = '/messages';
  static const profile = '/profile';
  static const wallet = '/wallet';
  static const discover = '/discover';
  static const notifications = '/notifications';
  static const reseller = '/reseller';
  static const recharge = '/recharge';
  static const vip = '/vip';
  static String room(String id) => '/room/$id';
}

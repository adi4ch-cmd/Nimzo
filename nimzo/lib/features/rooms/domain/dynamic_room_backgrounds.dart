/// Safe background URLs selected by existing built-in room theme names.
/// Remote JSON can replace approved presentation assets only; it is never
/// allowed to change mic permissions, coins or voice sessions.
String? nimzoApprovedRoomBackground(
  Map<String, Map<String, dynamic>> settings,
  String theme,
) {
  const knownThemes = {
    'nimzo_white',
    'sage',
    'ocean',
    'lavender',
    'rose',
    'midnight',
    'premium_black',
    'luxury',
  };
  if (!knownThemes.contains(theme)) return null;
  final payload = settings['room.backgrounds'];
  final images = payload?['themes'];
  if (images is! Map) return null;
  final candidate = images[theme];
  if (candidate is! String || candidate.length > 2048) return null;
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) return null;
  return uri.toString();
}

import '../../../core/services/published_catalog_image.dart';
import '../../../core/services/media_publication.dart';
import '../../../core/services/approved_media_bytes.dart';

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
  if (candidate is Map) {
    final row = Map<String, dynamic>.from(candidate);
    final url = row['url'];
    try {
      final publication = PublishedCatalogImage.parse(row)?.publication;
      if (publication == null ||
          publication.byteLength > 8 * 1024 * 1024 ||
          url is! String ||
          !ApprovedMediaBytes.isSafeUrl(url) ||
          !Uri.parse(url).path.contains(publication.sha256Hex)) return null;
      return url;
    } catch (_) {
      return null;
    }
  }
  if (candidate is! String || candidate.length > 2048) return null;
  return ApprovedMediaBytes.isSafeUrl(candidate) ? candidate : null;
}

ApprovedMediaPublication? nimzoApprovedRoomBackgroundPublication(
    Map<String, Map<String, dynamic>> settings, String theme) {
  if (nimzoApprovedRoomBackground(settings, theme) == null) return null;
  final themes = settings['room.backgrounds']?['themes'];
  final row = themes is Map ? themes[theme] : null;
  if (row is! Map) return null;
  return parseMediaPublication(Map<String, dynamic>.from(row), kind: 'image');
}

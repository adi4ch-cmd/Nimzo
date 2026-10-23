import 'approved_media_bytes.dart';

/// Legacy records may omit metadata. Partial/malformed publications never
/// silently fall back to legacy network playback.
ApprovedMediaPublication? parseMediaPublication(Map<String, dynamic> row,
    {required String kind, String prefix = ''}) {
  final hash = row['${prefix}sha256'];
  final size = row['${prefix}byte_size'];
  final mime = row['${prefix}mime_type'];
  if (hash == null && size == null && mime == null) return null;
  if (hash is! String || size is! int || mime is! String) {
    throw const FormatException('Incomplete media publication');
  }
  final codec = kind == 'image'
      ? {'image/png': 'png', 'image/jpeg': 'jpeg', 'image/webp': 'webp'}[mime]
      : kind;
  if (codec == null)
    throw const FormatException('Unsupported image publication');
  final publication = ApprovedMediaPublication(
      sha256Hex: hash, byteLength: size, mimeType: mime, codec: codec);
  if (!publication.isValid)
    throw const FormatException('Invalid media publication');
  return publication;
}

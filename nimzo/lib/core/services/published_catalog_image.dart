import 'approved_media_bytes.dart';
import 'media_publication.dart';

/// Immutable image identity for owner-published presentation. Dates and rights
/// records are audit assertions; actual bytes are checked by PublishedImage.
class PublishedCatalogImage {
  const PublishedCatalogImage._(this.url, this.publication);
  final String url;
  final ApprovedMediaPublication publication;
  static const fields = {
    'url',
    'sha256',
    'byte_size',
    'mime_type',
    'rights_reference',
    'verified_at',
    'device_verified_at'
  };

  static PublishedCatalogImage? parse(Object? value) {
    if (value is! Map ||
        value.length != fields.length ||
        !value.keys.every(fields.contains)) return null;
    final url = value['url'], rights = value['rights_reference'];
    if (url is! String ||
        !ApprovedMediaBytes.isSafeUrl(url) ||
        Uri.parse(url).hasQuery ||
        rights is! String ||
        rights.trim().isEmpty ||
        rights.length > 500 ||
        value['verified_at'] is! String ||
        DateTime.tryParse(value['verified_at'] as String) == null ||
        value['device_verified_at'] is! String ||
        DateTime.tryParse(value['device_verified_at'] as String) == null)
      return null;
    try {
      final publication = parseMediaPublication(
          Map<String, dynamic>.from(value),
          kind: 'image');
      if (publication == null ||
          publication.byteLength > 4 * 1024 * 1024 ||
          !Uri.parse(url).path.contains(publication.sha256Hex)) return null;
      return PublishedCatalogImage._(url, publication);
    } on FormatException {
      return null;
    }
  }
}

/// Validate bytes before assigning an extension or a Storage content type.
(String, String) profileImageFormat(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
    return ('jpg', 'image/jpeg');
  }
  if (bytes.length >= 8 && bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
    return ('png', 'image/png');
  }
  if (bytes.length >= 12 && String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return ('webp', 'image/webp');
  }
  throw const FormatException('Choose a JPEG, PNG or WebP photo.');
}

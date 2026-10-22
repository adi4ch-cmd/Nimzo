import 'dart:io';

import 'approved_media_bytes.dart';

/// Pins native playback to the bytes verified before decoding, rather than
/// asking a native URL player to download a possibly changed object again.
class VerifiedMediaFile {
  VerifiedMediaFile._(this.file, this._directory);
  final File file;
  final Directory _directory;

  static Future<VerifiedMediaFile> create(
      String url, ApprovedMediaPublication publication) async {
    final bytes = await ApprovedMediaBytes.fetch(url, publication: publication);
    final directory = await Directory.systemTemp.createTemp('nimzo-verified-');
    try {
      final file = File('${directory.path}/${publication.sha256Hex}.mp4');
      await file.writeAsBytes(bytes, flush: true);
      return VerifiedMediaFile._(file, directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}

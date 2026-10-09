import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/supabase_provider.dart';
import '../../features/profile/profile_image_format.dart';

class StorageService {
  final SupabaseClient _db;
  StorageService(this._db);
  Future<String?> pickAndUpload(
    String bucket, {
    ImageSource source = ImageSource.gallery,
    String? roomId,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in again.');
    if (bucket == 'room-images' && (roomId == null || roomId.isEmpty))
      throw ArgumentError('A room is required for room artwork.');
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024)
      throw const FormatException('Choose a photo smaller than 10 MB.');
    final (extension, contentType) = profileImageFormat(bytes);
    final folder = bucket == 'room-images' ? roomId! : uid;
    final path = '$folder/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _db.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  }
}

final storageServiceProvider = Provider(
  (ref) => StorageService(ref.watch(sessionSupabaseProvider).client),
);

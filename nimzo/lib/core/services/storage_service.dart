import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_provider.dart';

/// Uploads to `<bucket>/<uid>/<timestamp>.jpg` and returns the storage PATH (not a URL).
class StorageService {
  final SupabaseClient _db;
  StorageService(this._db);
  Future<String?> pickAndUpload(String bucket) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    final path = '${_db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from(bucket).upload(path, File(x.path), fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }
}
final storageServiceProvider = Provider((ref) => StorageService(ref.watch(supabaseProvider)));

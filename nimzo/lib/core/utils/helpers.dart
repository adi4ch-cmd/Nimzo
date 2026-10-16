import 'package:supabase_flutter/supabase_flutter.dart';

/// Public URL from a backend storage path, never a hard-coded link.
String? storageUrl(SupabaseClient db, String bucket, String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final value = path.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) return value;
  return db.storage.from(bucket).getPublicUrl(value);
}

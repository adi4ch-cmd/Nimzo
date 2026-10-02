import 'package:supabase_flutter/supabase_flutter.dart';

/// Public URL from a backend storage path, never a hard-coded link.
String? storageUrl(SupabaseClient db, String bucket, String? path) =>
    path == null || path.isEmpty ? null : db.storage.from(bucket).getPublicUrl(path);

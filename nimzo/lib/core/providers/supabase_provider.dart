import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(supabaseProvider).auth.currentUser?.id);

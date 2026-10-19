import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';

/// Older posts were uploaded to moment-images before uploads moved to moments.
/// Keep both generations readable without rewriting a user's post or file.
class MomentPhoto extends ConsumerWidget {
  const MomentPhoto({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(supabaseProvider).storage;
    return Image.network(
      storage.from('moments').getPublicUrl(path),
      fit: fit,
      errorBuilder: (_, __, ___) => Image.network(
        storage.from('moment-images').getPublicUrl(path),
        fit: fit,
        errorBuilder: (_, __, ___) => const EmptyContent('Image unavailable'),
      ),
    );
  }
}

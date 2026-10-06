import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/utils/helpers.dart';

/// Only displays artwork explicitly assigned to a catalog record.
class GiftArtwork extends ConsumerWidget {
  final String? path;
  final double size;
  final String bucket;
  const GiftArtwork(
      {super.key, required this.path, this.size = 46, this.bucket = 'gifts'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = path?.trim();
    final missing = SizedBox(
      width: size,
      height: size,
      child: const Center(
          child: Text('Image unavailable',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 10))),
    );
    if (source == null || source.isEmpty) return missing;
    final local = source.startsWith('assets/gifts/');
    final url = local
        ? source
        : storageUrl(ref.watch(supabaseProvider), bucket, source)!;
    final svg = Uri.parse(url).path.toLowerCase().endsWith('.svg');
    return Semantics(
      label: 'Gift artwork',
      child: SizedBox(
        width: size,
        height: size,
        child: svg
            ? (local
                ? SvgPicture.asset(url,
                    fit: BoxFit.contain, errorBuilder: (_, __, ___) => missing)
                : SvgPicture.network(url,
                    fit: BoxFit.contain, errorBuilder: (_, __, ___) => missing))
            : (local
                ? Image.asset(url,
                    fit: BoxFit.contain, errorBuilder: (_, __, ___) => missing)
                : Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => missing)),
      ),
    );
  }
}

import '../../core/widgets/published_image.dart';
import '../../core/services/approved_media_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'hall_of_fame_gift.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'private_animal_gifts.dart';
import 'gift_repository.dart';

/// The retired gift galleries are intentionally unreachable. Keep these
/// helpers as safe compatibility shims for callers in older screens.
String? referenceGiftArtwork(String name) => null;
String? cinematicGiftArtwork(String name) => null;
String? originalNimzoGiftArtwork(String name) => null;
String? originalDragonPoster(String name) => null;

/// The Sports Car is the only active NIMZO room/profile/Moment gift.
String? freeGiftArtwork(String name) =>
    name.trim().toLowerCase() == 'sports car'
        ? 'assets/gifts/free/sports_car.png'
        : null;

class GiftArtwork extends StatelessWidget {
  final String name;
  final String? assetPath;
  const GiftArtwork(
      {super.key,
      required this.name,
      this.assetPath,
      this.publication,
      this.requiresPublication = false});
  final ApprovedMediaPublication? publication;
  final bool requiresPublication;

  @override
  Widget build(BuildContext context) {
    final supplied = assetPath;
    if (supplied != null && ApprovedMediaBytes.isSafeUrl(supplied)) {
      if (requiresPublication && publication == null)
        return const Icon(Icons.broken_image_outlined);
      return PublishedImage(url: supplied, publication: publication);
    }
    if (supplied != null &&
        supplied.startsWith('assets/') &&
        !supplied.contains('..') &&
        RegExp(r'\.(png|webp|jpe?g)$', caseSensitive: false)
            .hasMatch(supplied)) {
      return Image.asset(supplied,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.card_giftcard_outlined));
    }
    final protectedId = privateAnimalGiftIdForName(name);
    if (protectedId != null) {
      return Consumer(
        builder: (context, ref, _) => ref
            .watch(privateGiftThumbnailProvider(protectedId))
            .when(
              data: (url) => url == null
                  ? const SizedBox.shrink()
                  : PublishedImage(
                      url: url, unavailable: const Icon(Icons.card_giftcard)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Icon(Icons.card_giftcard),
            ),
      );
    }
    if (name.trim().toLowerCase() == hallOfFameGiftName.toLowerCase()) {
      return SvgPicture.asset(
        hallOfFameIconAsset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            const Icon(Icons.workspace_premium, color: Color(0xffdfb968)),
      );
    }
    final path = freeGiftArtwork(name);
    // A stale gift event or outdated local catalog must never revive removed
    // gift images or display their custom/remote assets.
    if (path == null) return const SizedBox.shrink();
    return Image.asset(
      path,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.directions_car_rounded, color: Color(0xffdeba74)),
    );
  }
}

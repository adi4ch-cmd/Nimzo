import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'hall_of_fame_gift.dart';
import 'zodiac_gifts.dart';

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
  const GiftArtwork({super.key, required this.name, this.assetPath});

  @override
  Widget build(BuildContext context) {
    if (name.trim().toLowerCase() == hallOfFameGiftName.toLowerCase()) {
      return SvgPicture.asset(hallOfFameIconAsset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const Icon(Icons.workspace_premium, color: Color(0xffdfb968)),
      );
    }
    final normalized = name.trim().toLowerCase();
    if (normalized == libraGiftName.toLowerCase() || normalized == ariesGiftName.toLowerCase()) {
      return SvgPicture.asset(
        normalized == libraGiftName.toLowerCase()
            ? libraGiftIconAsset
            : ariesGiftIconAsset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const Icon(Icons.auto_awesome, color: Color(0xffe0c188)),
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
      errorBuilder: (_, __, ___) => const Icon(
        Icons.directions_car_rounded,
        color: Color(0xffdeba74),
      ),
    );
  }
}

import 'package:flutter/material.dart';

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

// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

import 'gift_svga_overlay.dart';

String? referenceGiftArtwork(String name) {
  final index = switch (name.trim().toLowerCase()) {
    'spark' => 0,
    'rose' || 'eternal rose' => 1,
    'heart' || 'love heart' => 2,
    'wonder box' => 3,
    'rocket' || 'star rocket' => 4,
    'golden king' => 5,
    'royal couple' => 6,
    'diamond' || 'royal diamond' => 7,
    'royal dragon' || 'legend dragon' => 8,
    'crown' || 'emperor crown' => 9,
    'galaxy empire' => 10,
    'dream kingdom' => 11,
    'world crown' => 12,
    _ => null,
  };
  return index == null ? null : 'assets/reference/gift/$index.jpg';
}

/// Named, byte-pinned original icons from the MIT-licensed Agora demo.
/// Sports Car artwork is extracted from a matching, MIT-licensed SVGA frame.
/// No image is assigned to an unrelated catalog name.
String? freeGiftArtwork(String name) => switch (name.trim().toLowerCase()) {
      'heart' => 'assets/gifts/free/heart.png',
      'rose' => 'assets/gifts/free/rose.png',
      'diamond' => 'assets/gifts/free/diamond.png',
      'crown' => 'assets/gifts/free/crown.png',
      'rocket' => 'assets/gifts/free/rocket.png',
      'sports car' => 'assets/gifts/free/sports_car.png',
      _ => null,
    };

/// All fourteen newly illustrated NIMZO gifts use original branded vectors.
/// Keeping this whitelist explicit prevents unrelated catalog entries from
/// showing another gift's picture.
String? originalNimzoGiftArtwork(String name) {
  final slug = switch (name.trim().toLowerCase()) {
    'kiss' => 'kiss',
    'coffee' => 'coffee',
    'cat' => 'cat',
    'birthday cake' => 'birthday_cake',
    'teddy bear' => 'teddy_bear',
    'gift box' => 'gift_box',
    'panda' => 'panda',
    'diamond ring' => 'diamond_ring',
    'golden palace' => 'golden_palace',
    'private jet' => 'private_jet',
    'luxury yacht' => 'luxury_yacht',
    'dragon' => 'dragon',
    'golden dragon' => 'golden_dragon',
    'phoenix' => 'phoenix',
    _ => null,
  };
  return slug == null ? null
      : 'assets/nimzo_custom_gifts/' + slug + '.svg';
}

/// Actual poster frames generated from the licensed original videos.
String? originalDragonPoster(String name) =>
    switch (name.trim().toLowerCase()) {
      'dragon' => 'assets/gifts/dragon_1m_poster.webp',
      'golden dragon' => 'assets/gifts/golden_dragon_5m_poster.webp',
      _ => null,
    };

class GiftArtwork extends StatelessWidget {
  final String name;
  final String? assetPath;
  const GiftArtwork({super.key, required this.name, this.assetPath});
  @override
  Widget build(BuildContext context) {
    // The original Yo2 APK does not bundle per-gift catalog images. Keep
    // the real catalog name readable rather than inventing a replacement icon.
    final unavailable = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: RichText(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xffe6bc58),
            ),
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    final path =
        assetPath ?? originalNimzoGiftArtwork(name) ?? freeGiftArtwork(name) ?? originalDragonPoster(name) ?? referenceGiftArtwork(name);
    if (path == null) {
      final svga = freeGiftAnimationForName(name);
      if (svga != null) return SVGAEasyPlayer(assetsName: svga, fit: BoxFit.contain);
      return unavailable;
    }
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(path, fit: BoxFit.contain);
    }
    if (path.endsWith('.svga')) {
      return SVGAEasyPlayer(assetsName: path, fit: BoxFit.contain);
    }
    if (Uri.tryParse(path)?.scheme == 'https')
      return Image.network(path, errorBuilder: (_, __, ___) => unavailable);
    if (path.startsWith('assets/'))
      return Image.asset(path, errorBuilder: (_, __, ___) => unavailable);
    return unavailable;
  }
}

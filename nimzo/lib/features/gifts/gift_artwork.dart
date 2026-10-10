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
        assetPath ?? originalDragonPoster(name) ?? referenceGiftArtwork(name);
    if (path == null) {
      final svga = freeGiftAnimationForName(name);
      if (svga != null) return SVGAEasyPlayer(assetsName: svga, fit: BoxFit.contain);
      return unavailable;
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

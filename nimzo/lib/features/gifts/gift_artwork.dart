import 'package:flutter/material.dart';

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
String? originalDragonPoster(String name) => switch (name.trim().toLowerCase()) {
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
    const unavailable = Center(
      child: Text(
        'Artwork unavailable',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11),
      ),
    );
    final path = assetPath ?? originalDragonPoster(name) ?? referenceGiftArtwork(name);
    if (path == null) return unavailable;
    if (Uri.tryParse(path)?.scheme == 'https')
      return Image.network(path, errorBuilder: (_, __, ___) => unavailable);
    if (path.startsWith('assets/'))
      return Image.asset(path, errorBuilder: (_, __, ___) => unavailable);
    return unavailable;
  }
}
